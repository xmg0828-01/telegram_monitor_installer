cat > install_telegram_monitor.sh << 'EOF'
#!/bin/bash

# Telegram 群组监控转发工具安装脚本
# 作者: 沙龙新加坡

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 权限运行此脚本${NC}"
  echo "例如: sudo bash $0"
  exit 1
fi

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  Telegram 群组监控转发工具安装器  ${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

WORK_DIR="/opt/telegram-monitor"
echo -e "${YELLOW}创建工作目录: $WORK_DIR${NC}"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo -e "${YELLOW}安装系统依赖...${NC}"
apt update
apt install -y python3-pip

echo -e "${YELLOW}安装 Python 依赖...${NC}"
pip3 install --upgrade telethon python-telegram-bot

echo -e "${YELLOW}创建 README.md${NC}"
cat > $WORK_DIR/README.md << 'EOL'
# Telegram 群组监控转发工具

这是一个基于 Telethon 和 Python-Telegram-Bot 的 Telegram 群组监控和消息转发工具。
EOL

echo -e "${YELLOW}创建 requirements.txt${NC}"
cat > $WORK_DIR/requirements.txt << 'EOL'
telethon>=1.29.2
python-telegram-bot>=20.0
EOL

echo -e "${YELLOW}创建配置文件模板...${NC}"
cat > $WORK_DIR/config.example.json << 'EOL'
{
  "api_id": "YOUR_API_ID",
  "api_hash": "YOUR_API_HASH",
  "bot_token": "YOUR_BOT_TOKEN",
  "target_ids": [-1002243984935],
  "keywords": ["example", "keyword1"],
  "watch_ids": ["channelname"],
  "whitelist": [123456789]
}
EOL

echo -e "${YELLOW}创建 channel_forwarder.py${NC}"
cat > $WORK_DIR/channel_forwarder.py << 'EOL'
#!/usr/bin/env python3
from telethon import TelegramClient, events
from datetime import datetime
import json
import os
import sys

CONFIG_FILE = 'config.json'

def load_config():
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"错误: 未找到配置文件 {CONFIG_FILE}")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"错误: 配置文件 {CONFIG_FILE} 格式不正确")
        sys.exit(1)

config = load_config()
api_id = config.get('api_id')
api_hash = config.get('api_hash')

if not api_id or not api_hash:
    print("请配置 api_id 和 api_hash")
    sys.exit(1)

client = TelegramClient('channel_forward_session', api_id, api_hash)

@client.on(events.NewMessage)
async def handler(event):
    config = load_config()
    msg = event.message.message
    if not msg:
        return

    from_chat = getattr(event.chat, 'username', None) or str(getattr(event, 'chat_id', ''))
    if from_chat not in config["watch_ids"] and str(event.chat_id) not in config["watch_ids"]:
        return

    for keyword in config["keywords"]:
        if keyword.lower() in msg.lower():
            chat = await event.get_chat()
            chat_title = getattr(chat, 'title', '未知标题')
            chat_username = f"@{chat.username}" if getattr(chat, 'username', None) else f"(ID: {event.chat_id})"
            chat_type = "超级群组" if getattr(chat, 'megagroup', False) else "普通群组/频道"
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            print("\n" + "=" * 40)
            print(f"📍 来源: {chat_title} {chat_username}")
            print(f"🏷️ 类型: {chat_type}")
            print(f"🔑 触发关键词: {keyword}")
            print(f"⏰ 时间: {timestamp}")
            print(f"💬 消息内容: {msg[:100]}...")
            print("=" * 40)

            info_message = (
                f"📍 来源: {chat_title} {chat_username}\n"
                f"🏷️ 类型: {chat_type}\n"
                f"🔑 触发关键词: {keyword}\n"
                f"⏰ 时间: {timestamp}"
            )

            for target in config["target_ids"]:
                try:
                    await client.send_message(target, info_message)
                    await client.forward_messages(target, event.message)
                    print(f"✅ 成功转发到 {target}")
                except Exception as e:
                    print(f"❌ 转发失败: {e}")
            break

print(">>> 正在监听关键词转发 ...")
if __name__ == "__main__":
    try:
        client.start()
        client.run_until_disconnected()
    except Exception as e:
        print(f"异常退出: {e}")
EOL

echo -e "${YELLOW}创建 .gitignore${NC}"
cat > $WORK_DIR/.gitignore << 'EOL'
config.json
*.session
__pycache__/
*.pyc
*.log
EOL

echo -e "${YELLOW}设置执行权限${NC}"
chmod +x $WORK_DIR/channel_forwarder.py

echo -e "${YELLOW}创建 systemd 服务${NC}"
cat > /etc/systemd/system/channel_forwarder.service << EOF
[Unit]
Description=Telegram Channel Forwarder Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 ${WORK_DIR}/channel_forwarder.py
WorkingDirectory=${WORK_DIR}
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable channel_forwarder.service

echo ""
echo -e "${GREEN}现在进行Telegram API配置${NC}"
echo ""

read -p "API ID: " API_ID
read -p "API Hash: " API_HASH
read -p "Bot Token: " BOT_TOKEN
read -p "管理员ID: " ADMIN_ID
read -p "关键词 (空格分隔): " KEYWORDS
read -p "监听源 (空格分隔): " WATCH_IDS
read -p "转发目标 (空格分隔): " TARGET_IDS

KEYWORDS_JSON=$(printf '"%s", ' $KEYWORDS | sed 's/, $//')
WATCH_JSON=$(printf '"%s", ' $WATCH_IDS | sed 's/, $//')
TARGET_JSON=$(printf '%s, ' $TARGET_IDS | sed 's/, $//')

cat > $WORK_DIR/config.json << EOF
{
  "api_id": "${API_ID}",
  "api_hash": "${API_HASH}",
  "bot_token": "${BOT_TOKEN}",
  "target_ids": [${TARGET_JSON}],
  "keywords": [${KEYWORDS_JSON}],
  "watch_ids": [${WATCH_JSON}],
  "whitelist": [${ADMIN_ID}]
}
EOF

echo ""
echo -e "${GREEN}✅ 配置完成！${NC}"
echo -e "${YELLOW}现在运行以下命令登录 Telegram:${NC}"
echo -e "  ${BLUE}cd ${WORK_DIR} && python3 channel_forwarder.py${NC}"
echo -e "${YELLOW}登录后启动服务:${NC}"
echo -e "  ${BLUE}systemctl start channel_forwarder${NC}"
echo -e "${YELLOW}查看服务状态:${NC}"
echo -e "  ${BLUE}systemctl status channel_forwarder${NC}"
echo ""
EOF
