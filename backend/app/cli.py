"""Server-side management commands. There is deliberately no public admin sign-up.

    python -m app.cli create-admin --email admin@example.org --name "System Admin"
    python -m app.cli seed-demo          # development only: DEMO accounts, clearly labelled
    python -m app.cli run-reminders
"""

import argparse
import getpass
import os
import sys
from datetime import date

from sqlalchemy import select

from .config import get_settings
from .db import SessionLocal, init_db
from .models import Doctor, Patient, User
from .security import PASSWORD_RULES, hash_password, password_is_strong, random_code
from .services.reminders import run_reminders


def create_admin(email: str, name: str) -> None:
    password = os.environ.get("SUSTHITI_ADMIN_PASSWORD") or getpass.getpass("Admin password: ")
    if not password_is_strong(password):
        sys.exit(f"Password must be {PASSWORD_RULES}.")
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.email == email.lower())):
            sys.exit("A user with that email already exists.")
        db.add(User(email=email.lower(), password_hash=hash_password(password), role="admin", full_name=name))
        db.commit()
    print(f"Admin {email} created.")


def seed_demo() -> None:
    """Creates three DEMO accounts for local development only. They are flagged is_demo and
    shown with a DEMO badge in the app. Nothing medical is pre-filled."""
    if get_settings().is_production:
        sys.exit("Refusing to seed demo accounts in production.")
    password = os.environ.get("SUSTHITI_DEMO_PASSWORD", "Demo@12345")
    with SessionLocal() as db:
        def ensure(email, role, name):
            user = db.scalar(select(User).where(User.email == email))
            if user:
                return user, False
            user = User(email=email, password_hash=hash_password(password), role=role, full_name=name, is_demo=True)
            db.add(user)
            db.flush()
            return user, True

        admin, _ = ensure("demo.admin@susthiti.test", "admin", "Demo Admin")
        doc_user, created = ensure("demo.doctor@susthiti.test", "doctor", "Demo Doctor")
        if created:
            db.add(Doctor(user_id=doc_user.id, doctor_code=random_code("SUS-D"), specialization="Endocrinology (DEMO)"))
        pat_user, created = ensure("demo.patient@susthiti.test", "patient", "Demo Patient")
        if created:
            db.add(Patient(user_id=pat_user.id, patient_code=random_code("SUS-P"), date_of_birth=date(1985, 5, 14), gender="Male"))
        db.commit()
        patient = db.scalar(select(Patient).where(Patient.user_id == pat_user.id))
        print("DEMO accounts (development only):")
        print(f"  demo.admin@susthiti.test / demo.doctor@susthiti.test / demo.patient@susthiti.test  password: {password}")
        print(f"  Demo patient ID: {patient.patient_code}  name: Demo Patient")


def main() -> None:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    admin = sub.add_parser("create-admin")
    admin.add_argument("--email", required=True)
    admin.add_argument("--name", required=True)
    sub.add_parser("seed-demo")
    sub.add_parser("run-reminders")
    args = parser.parse_args()
    init_db()
    if args.command == "create-admin":
        create_admin(args.email, args.name)
    elif args.command == "seed-demo":
        seed_demo()
    elif args.command == "run-reminders":
        with SessionLocal() as db:
            print(f"Sent {run_reminders(db)} reminders.")


if __name__ == "__main__":
    main()
