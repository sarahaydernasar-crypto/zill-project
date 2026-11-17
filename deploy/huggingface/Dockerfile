# خادم ظِلّ على Hugging Face Spaces.
# يأخذ الكود من فرع flutter-frontend في المستودع العام عند كل بناء،
# فلتحديث الخادم بعد رفع كود جديد: Settings ثم Factory rebuild.
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Spaces تشغّل الحاوية بمستخدم رقمه 1000
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user PATH=/home/user/.local/bin:$PATH PYTHONPATH=src
WORKDIR /home/user/app

RUN git clone --depth 1 --branch flutter-frontend \
    https://github.com/sarahaydernasar-crypto/zill-project.git .
RUN pip install --no-cache-dir --user -r requirements-server.txt

EXPOSE 7860
CMD ["uvicorn", "project.main:app", "--host", "0.0.0.0", "--port", "7860", "--proxy-headers", "--forwarded-allow-ips", "*"]
