#!/bin/bash

# Telegram 群组监控转发工具安装脚本 - 带消息链接版本
# 作者: 沙龙新加坡

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否为 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 权限运行此脚本${NC}"
  echo "例如: sudo bash $0"
  exit 1
fi

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  Telegram 群组监控转发工具安装器  ${NC}"
echo -e "${BLUE}        带消息链接版本 v2.1         ${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# 创建工作目录
WORK_DIR="/opt/telegram-monitor"
echo -e "${YELLOW}创建工作目录: $WORK_DIR${NC}"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 安装依赖
echo -e "${YELLOW}安装系统依赖...${NC}"
apt update
apt install -y python3-pip python3-venv python3-full

# 创建虚拟环境
echo -e "${YELLOW}创建Python虚拟环境...${NC}"
python3 -m venv telegram_env
source telegram_env/bin/activate

echo -e "${YELLOW}安装 Python 依赖...${NC}"
pip install --upgrade pip
pip install telethon python-telegram-bot

# 创建带消息链接的 channel_forwarder.py
echo -e "${YELLOW}创建 channel_forwarder.py (带消息链接)${NC}"
cat > $WORK_DIR/channel_forwarder.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'telegram_env/lib/python3.11/site-packages'))

from telethon import TelegramClient, events
from datetime import datetime
import json
import asyncio
import signal

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

client = None
running = True

def signal_handler(signum, frame):
    global running, client
    print("\n收到停止信号，正在优雅关闭...")
    running = False
    if client and client.is_connected():
        asyncio.create_task(client.disconnect())

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def create_message_link(chat_entity, message_id):
    """创建消息链接"""
    try:
        if hasattr(chat_entity, 'username') and chat_entity.username:
            return f"https://t.me/{chat_entity.username}/{message_id}"
        elif hasattr(chat_entity, 'id'):
            chat_id = str(chat_entity.id)
            if chat_id.startswith('-100'):
                chat_id = chat_id[4:]
            return f"https://t.me/c/{chat_id}/{message_id}"
        else:
            return None
    except Exception as e:
        print(f"创建消息链接失败: {e}")
        return None

async def main():
    global client, running
    
    config = load_config()
    api_id = config.get('api_id')
    api_hash = config.get('api_hash')
    
    if not api_id or not api_hash:
        print("错误: 请在配置文件中设置有效的 api_id 和 api_hash")
        sys.exit(1)
    
    client = TelegramClient('channel_forward_session', api_id, api_hash)
    
    @client.on(events.NewMessage)
    async def handler(event):
        if not running:
            return
            
        try:
            config = load_config()
            msg = event.message.message
            if not msg:
                return
            
            from_chat = getattr(event.chat, 'username', None) or str(getattr(event, 'chat_id', ''))
            
            if from_chat not in config["watch_ids"] and str(event.chat_id) not in config["watch_ids"]:
                return
            
            for keyword in config["keywords"]:
                if keyword.lower() in msg.lower():
                    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 命中关键词: {keyword}")
                    print(f"来源: {from_chat}")
                    print(f"消息内容: {msg[:100]}...")
                    
                    try:
                        chat_entity = await client.get_entity(event.chat_id)
                        
                        if hasattr(chat_entity, 'username') and chat_entity.username:
                            source_info = f"@{chat_entity.username}"
                            if hasattr(chat_entity, 'title'):
                                source_info += f" ({chat_entity.title})"
                        elif hasattr(chat_entity, 'title'):
                            source_info = chat_entity.title
                        else:
                            source_info = f"群组ID: {event.chat_id}"
                        
                        sender_info = ""
                        if event.sender:
                            if hasattr(event.sender, 'username') and event.sender.username:
                                sender_info = f"@{event.sender.username}"
                            elif hasattr(event.sender, 'first_name'):
                                sender_info = event.sender.first_name
                                if hasattr(event.sender, 'last_name') and event.sender.last_name:
                                    sender_info += f" {event.sender.last_name}"
                            else:
                                sender_info = f"用户ID: {event.sender_id}"
                        
                        message_link = create_message_link(chat_entity, event.message.id)
                        
                        source_header = f"📢 消息来源: {source_info}"
                        if sender_info:
                            source_header += f"\n👤 发送者: {sender_info}"
                        source_header += f"\n🕐 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                        source_header += f"\n🔑 匹配关键词: {keyword}"
                        
                        if message_link:
                            source_header += f"\n🔗 消息链接: {message_link}"
                        else:
                            source_header += f"\n💬 消息ID: {event.message.id}"
                        
                        source_header += "\n" + "─" * 40 + "\n"
                        
                        for target in config["target_ids"]:
                            try:
                                await client.send_message(target, source_header)
                                await client.forward_messages(target, event.message)
                                print(f"✅ 成功转发到 {target} (包含消息链接)")
                            except Exception as e:
                                print(f"❌ 转发到 {target} 失败: {e}")
                                
                    except Exception as e:
                        print(f"❌ 获取来源信息失败: {e}")
                        simple_source = f"📢 消息来源: {from_chat}\n🕐 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n🔑 匹配关键词: {keyword}\n💬 消息ID: {event.message.id}\n" + "─" * 40 + "\n"
                        
                        for target in config["target_ids"]:
                            try:
                                await client.send_message(target, simple_source)
                                await client.forward_messages(target, event.message)
                                print(f"✅ 成功转发到 {target} (简单来源信息)")
                            except Exception as e:
                                print(f"❌ 转发到 {target} 失败: {e}")
                    
                    break
                    
        except Exception as e:
            print(f"处理消息时发生错误: {e}")
    
    print(">>> 正在监听关键词转发 (带消息链接功能) ...")
    print(">>> 如果是首次运行，请按照提示完成 Telegram 登录")
    print(">>> 按 Ctrl+C 可停止运行")
    
    try:
        await client.start()
        print("✅ 客户端启动成功，开始监听...")
        
        while running:
            await asyncio.sleep(1)
            
    except KeyboardInterrupt:
        print("\n收到键盘中断信号")
    except Exception as e:
        print(f"发生错误: {e}")
    finally:
        if client and client.is_connected():
            await client.disconnect()
        print("程序已停止")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n程序已停止")
        sys.exit(0)
    except Exception as e:
        print(f"发生错误: {e}")
        sys.exit(1)
EOF

# 创建 bot_manager.py
echo -e "${YELLOW}创建 bot_manager.py${NC}"
cat > $WORK_DIR/bot_manager.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'telegram_env/lib/python3.11/site-packages'))

from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes
import json
import logging

CONFIG_FILE = 'config.json'

logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s', level=logging.INFO)

def load_config():
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        logging.error(f"未找到配置文件 {CONFIG_FILE}")
        sys.exit(1)
    except json.JSONDecodeError:
        logging.error(f"配置文件 {CONFIG_FILE} 格式不正确")
        sys.exit(1)

def save_config(config):
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)

def is_allowed(uid):
    return uid in load_config().get("whitelist", [])

async def add_common(update, context, key):
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("❌ 权限不足")
        return
    
    try:
        value = context.args[0]
        config = load_config()
        
        if key in ["target_ids", "whitelist"] and value.lstrip('-').isdigit():
            value = int(value)
        
        if value not in config[key]:
            config[key].append(value)
            save_config(config)
            await update.message.reply_text(f"✅ 已添加到 {key}: {value}")
        else:
            await update.message.reply_text("⚠️ 已存在")
    except IndexError:
        await update.message.reply_text("❌ 格式错误，请提供参数")
    except Exception as e:
        await update.message.reply_text(f"❌ 发生错误: {e}")

async def del_common(update, context, key):
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("❌ 权限不足")
        return
    
    try:
        value = context.args[0]
        config = load_config()
        
        if key in ["target_ids", "whitelist"] and value.lstrip('-').isdigit():
            value = int(value)
        
        if value in config[key]:
            config[key].remove(value)
            save_config(config)
            await update.message.reply_text(f"✅ 已从 {key} 删除: {value}")
        else:
            await update.message.reply_text("⚠️ 不存在")
    except IndexError:
        await update.message.reply_text("❌ 格式错误，请提供参数")
    except Exception as e:
        await update.message.reply_text(f"❌ 发生错误: {e}")

async def add_kw(update, context):
    await add_common(update, context, "keywords")

async def del_kw(update, context):
    await del_common(update, context, "keywords")

async def add_group(update, context):
    await add_common(update, context, "target_ids")

async def del_group(update, context):
    await del_common(update, context, "target_ids")

async def add_watch(update, context):
    await add_common(update, context, "watch_ids")

async def del_watch(update, context):
    await del_common(update, context, "watch_ids")

async def show_config(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("❌ 权限不足")
        return
    
    config = load_config()
    text = (
        f"📋 当前配置:\n\n"
        f"🔑 关键词：{config['keywords']}\n\n"
        f"🎯 转发目标：{config['target_ids']}\n\n"
        f"👀 监听源：{config['watch_ids']}\n\n"
        f"👤 白名单：{config['whitelist']}\n\n"
        f"🔗 功能: 自动添加消息链接"
    )
    await update.message.reply_text(text)

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_allowed(update.effective_user.id):
        await update.message.reply_text("❌ 权限不足")
        return
    
    text = (
        "🔍 命令列表:\n\n"
        "/addkw <关键词> - 添加关键词\n"
        "/delkw <关键词> - 删除关键词\n"
        "/addgroup <群组ID> - 添加转发目标\n"
        "/delgroup <群组ID> - 删除转发目标\n"
        "/addwatch <群组ID或用户名> - 添加监听群组\n"
        "/delwatch <群组ID或用户名> - 删除监听群组\n"
        "/show - 显示当前配置\n"
        "/help - 显示帮助菜单\n\n"
        "🔗 新功能: 转发消息时会自动包含原消息链接"
    )
    await update.message.reply_text(text)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = (
        "👋 欢迎使用 Telegram 群组监控转发机器人!\n\n"
        "🔗 新版本增加了消息链接功能，转发的消息会包含原始消息的直达链接！\n\n"
        "使用 /help 查看可用命令。"
    )
    await update.message.reply_text(text)

def main():
    try:
        config = load_config()
        token = config.get('bot_token')
        
        if not token:
            logging.error("错误: 请在配置文件中设置有效的 bot_token")
            sys.exit(1)
        
        if not config.get('whitelist'):
            logging.error("错误: 请在配置文件中添加至少一个白名单用户ID")
            sys.exit(1)
        
        app = ApplicationBuilder().token(token).build()
        
        app.add_handler(CommandHandler("start", start))
        app.add_handler(CommandHandler("addkw", add_kw))
        app.add_handler(CommandHandler("delkw", del_kw))
        app.add_handler(CommandHandler("addgroup", add_group))
        app.add_handler(CommandHandler("delgroup", del_group))
        app.add_handler(CommandHandler("addwatch", add_watch))
        app.add_handler(CommandHandler("delwatch", del_watch))
        app.add_handler(CommandHandler("show", show_config))
        app.add_handler(CommandHandler("help", help_cmd))
        
        logging.info("Bot管理器已启动 (支持消息链接功能)")
        app.run_polling()
        
    except Exception as e:
        logging.error(f"发生错误: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

# 创建启动脚本
echo -e "${YELLOW}创建启动脚本${NC}"
cat > $WORK_DIR/start_forwarder.sh << 'EOF'
#!/bin/bash
cd /opt/telegram-monitor
source telegram_env/bin/activate
python3 channel_forwarder.py
EOF

cat > $WORK_DIR/start_bot_manager.sh << 'EOF'
#!/bin/bash
cd /opt/telegram-monitor
source telegram_env/bin/activate
python3 bot_manager.py
EOF

# 设置权限
chmod +x $WORK_DIR/channel_forwarder.py
chmod +x $WORK_DIR/bot_manager.py
chmod +x $WORK_DIR/start_forwarder.sh
chmod +x $WORK_DIR/start_bot_manager.sh

# 创建系统服务
cat > /etc/systemd/system/channel_forwarder.service << EOF
[Unit]
Description=Telegram Channel Forwarder Service with Message Links
After=network.target

[Service]
ExecStart=${WORK_DIR}/start_forwarder.sh
WorkingDirectory=${WORK_DIR}
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/bot_manager.service << EOF
[Unit]
Description=Telegram Bot Manager Service with Message Links
After=network.target

[Service]
ExecStart=${WORK_DIR}/start_bot_manager.sh
WorkingDirectory=${WORK_DIR}
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable channel_forwarder.service
systemctl enable bot_manager.service

# 交互式配置
echo -e "${GREEN}现在进行Telegram API配置${NC}"

# 获取API ID
echo -e "${YELLOW}请输入您的 Telegram API ID${NC}"
echo "可从 https://my.telegram.org/apps 获取"
while true; do
    read -p "API ID: " API_ID
    if [ ! -z "$API_ID" ] && [[ "$API_ID" =~ ^[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}API ID 不能为空且必须是数字${NC}"
    fi
done

# 获取API Hash
echo -e "${YELLOW}请输入您的 Telegram API Hash${NC}"
while true; do
    read -p "API Hash: " API_HASH
    if [ ! -z "$API_HASH" ]; then
        break
    else
        echo -e "${RED}API Hash 不能为空${NC}"
    fi
done

# 获取Bot Token
echo -e "${YELLOW}请输入您的 Telegram Bot Token${NC}"
echo "从 BotFather 获取"
while true; do
    read -p "Bot Token: " BOT_TOKEN
    if [ ! -z "$BOT_TOKEN" ]; then
        break
    else
        echo -e "${RED}Bot Token 不能为空${NC}"
    fi
done

# 获取管理员ID
echo -e "${YELLOW}请输入管理员的 Telegram 用户ID${NC}"
echo "可以使用 @userinfobot 获取您的用户ID"
while true; do
    read -p "管理员ID: " ADMIN_ID
    if [ ! -z "$ADMIN_ID" ] && [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}管理员ID 不能为空且必须是数字${NC}"
    fi
done

# 设置关键词
echo -e "${YELLOW}请输入要监控的关键词 (用空格分隔)${NC}"
echo "例如: 重要 通知 紧急"
read -p "关键词: " KEYWORDS

if [ -z "$KEYWORDS" ]; then
    KEYWORDS="重要 通知"
    echo -e "${YELLOW}使用默认关键词: $KEYWORDS${NC}"
fi

# 设置监控源
echo -e "${YELLOW}请输入要监控的群组或频道 (用空格分隔)${NC}"
echo "可以是用户名(如 channelname)或ID(如 -1001234567890)"
while true; do
    read -p "监控源: " WATCH_IDS
    if [ ! -z "$WATCH_IDS" ]; then
        break
    else
        echo -e "${RED}至少需要一个监控源${NC}"
    fi
done

# 设置转发目标
echo -e "${YELLOW}请输入消息转发目标 (用空格分隔)${NC}"
echo "可以是用户ID或群组ID，群组ID通常是负数"
while true; do
    read -p "转发目标: " TARGET_IDS
    if [ ! -z "$TARGET_IDS" ]; then
        break
    else
        echo -e "${RED}至少需要一个转发目标${NC}"
    fi
done

# 创建配置文件
cat > $WORK_DIR/config.json << EOF
{
  "api_id": "${API_ID}",
  "api_hash": "${API_HASH}",
  "bot_token": "${BOT_TOKEN}",
  "target_ids": [${TARGET_IDS// /, }],
  "keywords": ["${KEYWORDS// /\", \"}"],
  "watch_ids": ["${WATCH_IDS// /\", \"}"],
  "whitelist": [${ADMIN_ID}]
}
EOF

echo ""
echo -e "${GREEN}✅ 配置完成！现在需要进行Telegram登录认证${NC}"
echo -e "${YELLOW}请运行以下命令进行登录:${NC}"
echo -e "${BLUE}cd ${WORK_DIR} && source telegram_env/bin/activate && python3 -c \"
import asyncio
from telethon import TelegramClient
import json

async def login():
    with open('config.json', 'r') as f:
        config = json.load(f)
    
    client = TelegramClient('channel_forward_session', config['api_id'], config['api_hash'])
    await client.start()
    me = await client.get_me()
    print(f'登录成功: {me.first_name}')
    await client.disconnect()

asyncio.run(login())
\"${NC}"

echo ""
echo -e "${GREEN}登录成功后，启动服务:${NC}"
echo -e "${BLUE}systemctl start channel_forwarder${NC}"
echo -e "${BLUE}systemctl start bot_manager${NC}"
echo ""
echo -e "${YELLOW}🔗 新功能: 转发消息时自动包含原始消息链接！${NC}"
echo -e "${GREEN}安装完成！${NC}"
