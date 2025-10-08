from database import db

print("Checking database tables...")
tables = db.execute_query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
print("Tables found:", [t['table_name'] for t in tables])

# Check if our specific tables exist
expected_tables = ['users', 'customers', 'calls', 'transcripts', 'ai_summaries', 'chat_messages']
for table in expected_tables:
    result = db.execute_query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = %s)", (table,))
    exists = result[0]['exists']
    print(f"Table '{table}': {'✓' if exists else '✗'}")