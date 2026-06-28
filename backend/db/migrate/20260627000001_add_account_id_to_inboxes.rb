class AddAccountIdToInboxes < ActiveRecord::Migration[8.1]
  def up
    add_column :inboxes, :account_id, :bigint

    # Backfill via conversations (each inbox belongs to the account of its conversations)
    execute <<-SQL
      UPDATE inboxes
      SET account_id = (
        SELECT account_id FROM conversations
        WHERE conversations.inbox_id = inboxes.id
        LIMIT 1
      )
    SQL

    # Inboxes without conversations: assign to the first account as fallback
    execute <<-SQL
      UPDATE inboxes
      SET account_id = (SELECT id FROM accounts ORDER BY id LIMIT 1)
      WHERE account_id IS NULL
    SQL

    add_index :inboxes, :account_id
  end

  def down
    remove_index :inboxes, :account_id
    remove_column :inboxes, :account_id
  end
end
