class CreateSearcherRecords < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        case
        when Redmine::Database.postgresql?
          create_table :searcher_records do |t|
            # common
            t.integer :project_id, null: false
            t.integer :original_id, null: false
            t.string :original_type, null: false
            t.timestamp :original_created_on
            t.timestamp :original_updated_on

            # projects
            t.string :name
            t.text :description
            t.string :identifier
            t.integer :status

            # news
            t.string :title
            t.string :summary
            # t.text :description

            # issues
            t.string :subject
            # t.text :description
            t.integer :author_id
            t.boolean :is_private
            t.integer :status_id
            t.integer :tracker_id

            # documents
            # t.string :title
            # t.text :description

            # changesets
            t.text :comments
            t.text :short_comments
            t.text :long_comments

            # messages
            # t.string :subject
            t.text :content

            # journals
            t.text :notes
            # t.integer :user_id # => author_id
            t.boolean :private_notes
            # t.integer :status_id

            # wiki_pages
            # t.string :title
            t.text :text # wiki_contents.text w/ latest version

            # custom_value
            t.text :value
            t.integer :custom_field_id

            # attachments
            t.integer :container_id
            t.string :container_type
            t.string :filename
            # t.text :description

            t.index([:original_id, :original_type], name: "index_searcher_records_unique", unique: true)
          end
        when Redmine::Database.mysql?
          create_table :searcher_records, options: "ENGINE=Mroonga" do |t|
            # common
            t.integer :project_id, null: false
            t.integer :original_id, null: false
            t.string :original_type, null: false, limit: 30
            t.timestamp :original_created_on
            t.timestamp :original_updated_on

            t.integer :project_id, null: false

            # projects
            t.string :name
            t.text :description, limit: 16.megabytes
            t.string :identifier
            t.integer :status

            # news
            t.string :title
            t.string :summary
            # t.text :description

            # issues
            t.integer :tracker_id
            t.string :subject
            # t.text :description
            t.integer :author_id
            t.boolean :is_private
            t.integer :status_id
            t.integer :tracker_id

            # documents
            # t.string :title
            # t.text :description

            # changesets
            t.text :comments, limit: 16.megabytes
            t.text :short_comments, limit: 16.megabytes
            t.text :long_comments, limit: 16.megabytes

            # messages
            # t.string :subject
            t.text :content

            # journals
            t.text :notes, limit: 16.megabytes
            # t.integer :user_id # => author_id
            t.boolean :private_notes
            # t.integer :status_id

            # wiki_pages
            # t.string :title
            t.text :text, limit: 16.megabytes # wiki_contents.text w/ latest version

            # custom_value
            t.text :value, limit: 16.megabytes
            t.integer :custom_field_id

            # attachments
            t.integer :container_id
            t.string :container_type, limit: 30
            t.string :filename, limit: 255
            # t.text :description

            t.index([:original_id, :original_type], name: "index_searcher_records_unique", unique: true)
          end
        end
        # Load data
        load_projects(table: "projects",
                      columns:                                %w[name identifier description status],
                      original_columns: %w[created_on updated_on name identifier description status])
        load_data(table: "news",
                  columns:                          %w[title summary description],
                  original_columns: %w[created_on NULL title summary description])
        load_data(table: "issues",
                  columns:                                %w[tracker_id subject description author_id status_id is_private],
                  original_columns: %w[created_on updated_on tracker_id subject description author_id status_id is_private])
        load_data(table: "documents",
                  columns:                          %w[title description],
                  original_columns: %w[created_on NULL title description])
        load_data(table: "changesets",
                  columns:                            %w[comments],
                  original_columns: %w[committed_on NULL comments])
        load_data(table: "messages",
                  columns:                                %w[subject content],
                  original_columns: %w[created_on updated_on subject content])
        load_data(table: "journals",
                  columns:                          %w[notes author_id is_private private_notes status_id],
                  original_columns: %w[created_on NULL notes user_id i.is_private private_notes i.status_id])
        load_data(table: "wiki_pages",
                  columns:                          %w[title text],
                  original_columns: %w[created_on NULL title c.text])
        load_custom_values(table: "custom_values",
                           columns:                    %w[value custom_field_id],
                           original_columns: %w[NULL NULL value custom_field_id])
        load_attachments(table: "attachments",
                         columns:                          %w[filename description],
                         original_columns: %w[created_on NULL filename description])
      end
      d.down do
        drop_table :searcher_records
      end
    end
  end

  private

  def load_projects(table:, columns:, original_columns:)
    sql = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}',id, #{transform(original_columns)} FROM #{table} AS base
    SQL
    execute(sql)
  end

  def load_data(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', project_id, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = case table
               when "changesets"
                 %Q[JOIN repositories AS r ON (base.repository_id = r.id)]
               when "messages"
                 %Q[JOIN boards AS b ON (base.board_id = b.id)]
               when "journals"
                 %Q[JOIN issues i ON (base.journalized_id = i.id)]
               when "wiki_pages"
                 <<-SQL
                 JOIN wikis AS w ON (base.wiki_id = w.id)
                 JOIN wiki_contents as c ON (base.id = c.page_id)
                 SQL
               else
                 ""
               end
    sql = "#{sql_base} #{sql_rest};"
    execute(sql)
  end

  def load_custom_values(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, status_id, is_private, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', r.project_id, status_id, is_private, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN issues AS i ON (base.customized_id = i.id)
    JOIN custom_fields AS f ON (base.custom_field_id = f.id)
    JOIN custom_fields_projects AS r ON (base.custom_field_id = r.custom_field_id)
    SQL
    sql = "#{sql_base} #{sql_rest} WHERE searchable = true;"
    execute(sql)

    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', r.project_id, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN projects AS p ON (base.customized_id = p.id)
    JOIN custom_fields AS f ON (base.custom_field_id = f.id)
    JOIN custom_fields_projects AS r ON (base.custom_field_id = r.custom_field_id)
    SQL
    sql = "#{sql_base} #{sql_rest} WHERE searchable = true;"
    execute(sql)
  end

  # container_type: Document, Issue, Message, News, Project, Version, WikiPage
  def load_attachments(table:, columns:, original_columns:)
    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, container_id, container_type, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.id, container_id, container_type, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN projects AS t ON (base.container_id = t.id AND base.container_type = 'Project')
    SQL
    execute("#{sql_base} #{sql_rest};")

    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, container_id, container_type, status_id, is_private, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.project_id, container_id, container_type, status_id, is_private, #{transform(original_columns)} FROM #{table} AS base
    SQL
    sql_rest = <<-SQL
    JOIN issues AS t ON (base.container_id = t.id AND base.container_type = 'Issue')
    SQL
    execute("#{sql_base} #{sql_rest};")

    sql_base = <<-SQL
    INSERT INTO searcher_records(original_id, original_type, project_id, container_id, container_type, original_created_on, original_updated_on, #{columns.join(", ")})
    SELECT base.id, '#{table.classify}', t.project_id, container_id, container_type, #{transform(original_columns)} FROM #{table} AS base
    SQL
    %w(documents news versions).each do |target|
      sql_rest = %Q[JOIN #{target} AS t ON (base.container_id = t.id AND base.container_type = '#{target.classify}')]
      execute("#{sql_base} #{sql_rest};")
    end

    sql_rest = <<-SQL
    JOIN messages AS m ON (base.container_id = m.id AND base.container_type = 'Message')
    JOIN boards AS t ON (m.board_id = t.id)
    SQL
    execute("#{sql_base} #{sql_rest};")

    sql_rest = <<-SQL
    JOIN wiki_pages AS p ON (base.container_id = p.id AND base.container_type = 'WikiPage')
    JOIN wikis AS t ON (p.wiki_id = t.id)
    SQL
    execute("#{sql_base} #{sql_rest};")
  end

  def transform(original_columns, prefix = "base")
    original_columns.map do |c|
      if c == "NULL" || c.include?(".")
        c
      else
        "#{prefix}.#{c}"
      end
    end.join(", ")
  end
end