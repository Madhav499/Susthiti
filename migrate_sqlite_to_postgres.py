import os
import sys
from pathlib import Path

from sqlalchemy import create_engine, MetaData, text

# Project root
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

# Import the actual SUSTHITI models
from backend.app.models import Base


SQLITE_URL = f"sqlite:///{ROOT / 'backend' / 'susthiti.db'}"
POSTGRES_URL = os.environ.get("RENDER_DATABASE_URL")

if not POSTGRES_URL:
    raise RuntimeError("RENDER_DATABASE_URL environment variable is missing.")

print("Connecting to databases...")

source_engine = create_engine(SQLITE_URL)
target_engine = create_engine(POSTGRES_URL.replace("postgresql://", "postgresql+psycopg://", 1))

print("Connected.")

# Use the application's real schema
metadata = Base.metadata

print("Creating PostgreSQL schema...")
metadata.create_all(target_engine)

print(f"Found {len(metadata.sorted_tables)} tables.")

# Copy data table-by-table in dependency order
with source_engine.connect() as source, target_engine.begin() as target:

    for table in metadata.sorted_tables:
        table_name = table.name

        print(f"\nMigrating: {table_name}")

        rows = source.execute(table.select()).mappings().all()

        if not rows:
            print("  Empty - skipped.")
            continue

        # Clear target table first
        target.execute(table.delete())

        data = [dict(row) for row in rows]

        # Insert in batches
        batch_size = 500

        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            target.execute(table.insert(), batch)

        print(f"  Copied {len(data)} rows.")

print("\n========================================")
print("DATABASE MIGRATION COMPLETED")
print("========================================")

# Verification
print("\nVerification:")

with source_engine.connect() as source, target_engine.connect() as target:
    for table in metadata.sorted_tables:
        name = table.name

        source_count = source.execute(
            text(f'SELECT COUNT(*) FROM "{name}"')
        ).scalar_one()

        target_count = target.execute(
            text(f'SELECT COUNT(*) FROM "{name}"')
        ).scalar_one()

        status = "OK" if source_count == target_count else "MISMATCH"

        print(
            f"{name}: "
            f"SQLite={source_count} "
            f"PostgreSQL={target_count} "
            f"[{status}]"
        )