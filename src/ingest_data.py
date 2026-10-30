import json
import bcrypt
from project.database import engine, SessionLocal
from project.models import Base, AreaDB, User

# إعادة إنشاء الجداول من الصفر لتجنب تعارض أنواع البيانات القديمة
Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)

def seed_all_data():
    db = SessionLocal()
    try:
        # 1. إدخال وتحديث البيانات المكانية
        with open("baghdad_results.json", "r", encoding="utf-8") as f:
            data = json.load(f)
            
        for item in data:
            area = AreaDB(
                name=item["name"],
                temperature=float(item["temperature"]),
                classification=item["classification"],
                ndvi=float(item["ndvi"]),
                planting_priority=float(item["planting_priority"])
            )
            db.add(area)
        print("✨ تم نقل وتحديث بيانات مناطق بغداد بنجاح!")

        # 2. إضافة وتثبيت حسابات الأدمن في قاعدة البيانات
        admins_data = [
            {"username": "admin1", "password": "123"},
            {"username": "admin2", "password": "456"}
        ]
        
        for data_admin in admins_data:
            existing_user = db.query(User).filter(User.username == data_admin["username"]).first()
            if not existing_user:
                pwd_bytes = data_admin["password"].encode('utf-8')
                hashed_pw = bcrypt.hashpw(pwd_bytes, bcrypt.gensalt()).decode('utf-8')
                
                new_admin = User(
                    username=data_admin["username"],
                    hashed_password=hashed_pw,
                    is_admin=True
                )
                db.add(new_admin)
                print(f"👤 تم تثبيت الأدمن: {data_admin['username']}")
            else:
                print(f"ℹ️ الأدمن {data_admin['username']} موجود مسبقاً.")

        db.commit()
        print("🚀 تم اكتمال إدخال البيانات وتثبيت حسابات الأدمن بنجاح تام!")

    except Exception as e:
        db.rollback()
        print(f"❌ حدث خطأ: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_all_data()