#!/bin/bash

# 简化版 Telegram 群组监控转发工具安装脚本

# 创建工作目录

mkdir -p /opt/telegram-monitor
cd /opt/telegram-monitor

# 创建 channel_forwarder.py 文件

cat > /opt/telegram-monitor/channel_forwarder.py << ‘EOF’
#!/usr/bin/env python3
from telethon import TelegramClient, events
from datetime import datetime
import json
import os
import sys

CONFIG_FILE = ‘config.json’

def load_config():
try:
with open(CONFIG_FILE, ‘r’) as f:
return json.load(f)
except FileNotFoundError:
print(“错误: 未找到配置文件 “ + CONFIG_FILE)
print(“请从 config.example.json 复制一份并填写相关信息”)
sys.exit(1)
except json.JSONDecodeError:
print(“错误: 配置文件 “ + CONFIG_FILE + “ 格式不正确”)
sys.exit(1)

# 加载配置

config = load_config()

# 从配置文件获取API凭据

api_id = config.get(‘api_id’)
api_hash = config.get(‘api_hash’)

if not api_id or not api_hash:
print(“错误: 请在配置文件中设置有效的 api_id 和 api_hash”)
print(“您可以从 https://my.telegram.org/apps 获取这些信息”)
sys.exit(1)

# 创建客户端实例

client = TelegramClient(‘channel_forward_session’, api_id, api_hash)

@client.on(events.NewMessage)
async def handler(event):
# 每次处理消息时重新加载配置，以便实时更新关键词等
config = load_config()

```
# 获取消息文本
msg = event.message.message
if not msg:
    return

# 获取来源信息
from_chat = getattr(event.chat, 'username', None) or str(getattr(event, 'chat_id', ''))

# 检查是否为监控目标
if from_chat not in config["watch_ids"] and str(event.chat_id) not in config["watch_ids"]:
    return

# 检查关键词
for keyword in config["keywords"]:
    if keyword.lower() in msg.lower():
        # 获取当前时间
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        print("[" + current_time + "] 命中关键词: " + keyword)
        print("来源: " + from_chat)
        print("消息内容: " + msg[:100] + "...")  # 只显示消息前100个字符
        
        # 准备添加来源和时间的前缀信息
        source_info = "来源群组: " + from_chat + "\n时间: " + current_time + "\n\n"
        
        # 转发到所有目标
        for target in config["target_ids"]:
            try:
                # 创建新消息，添加来源信息，同时保留原始消息内容
                await client.send_message(target, source_info + msg)
                print("✅ 成功转发到 " + str(target))
            except Exception as e:
                print("❌ 转发到 " + str(target) + " 失败: " + str(e))
        break  # 匹配一个关键词就跳出循环
```

print(”>>> 正在监听关键词转发 …”)
print(”>>> 如果是首次运行，请按照提示完成 Telegram 登录”)
print(”>>> 按 Ctrl+C 可停止运行”)

if **name** == “**main**”:
try:
client.start()
client.run_until_disconnected()
except KeyboardInterrupt:
print(”\n程序已停止”)
sys.exit(0)
except Exception as e:
print(“发生错误: “ + str(e))
sys.exit(1)
EOF

# 创建 bot_manager.py 文件

cat > /opt/telegram-monitor/bot_manager.py << ‘EOF’
#!/usr/bin/env python3
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes
import json
import logging
import sys

CONFIG_FILE = ‘config.json’

# 设置日志记录

logging.basicConfig(
format=’%(asctime)s - %(levelname)s - %(message)s’,
level=logging.INFO
)

def load_config():
try:
with open(CONFIG_FILE, ‘r’) as f:
return json.load(f)
except FileNotFoundError:
logging.error(“未找到配置文件 “ + CONFIG_FILE)
logging.error(“请从 config.example.json 复制一份并填写相关信息”)
sys.exit(1)
except json.JSONDecodeError:
logging.error(“配置文件 “ + CONFIG_FILE + “ 格式不正确”)
sys.exit(1)

def save_config(config):
with open(CONFIG_FILE, ‘w’) as f:
json.dump(config, f, indent=2)

def is_allowed(uid):
“”“检查用户是否在白名单中”””
return uid in load_config().get(“whitelist”, [])

async def add_kw(update, context):
“”“添加关键词”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
try:
    keyword = context.args[0]
    config = load_config()
    
    if keyword not in config["keywords"]:
        config["keywords"].append(keyword)
        save_config(config)
        await update.message.reply_text("✅ 已添加关键词: " + keyword)
    else:
        await update.message.reply_text("⚠️ 关键词已存在")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供关键词")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def del_kw(update, context):
“”“删除关键词”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
try:
    keyword = context.args[0]
    config = load_config()
    
    if keyword in config["keywords"]:
        config["keywords"].remove(keyword)
        save_config(config)
        await update.message.reply_text("✅ 已删除关键词: " + keyword)
    else:
        await update.message.reply_text("⚠️ 关键词不存在")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供关键词")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def add_group(update, context):
“”“添加转发目标群组”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
try:
    group_id = context.args[0]
    config = load_config()
    
    # 尝试将输入转换为整数（如果是数字ID）
    try:
        group_id = int(group_id)
    except ValueError:
        pass
    
    if group_id not in config["target_ids"]:
        config["target_ids"].append(group_id)
        save_config(config)
        await update.message.reply_text("✅ 已添加转发目标: " + str(group_id))
    else:
        await update.message.reply_text("⚠️ 转发目标已存在")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供群组ID")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def del_group(update, context):
“”“删除转发目标群组”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
try:
    group_id = context.args[0]
    config = load_config()
    
    # 尝试将输入转换为整数（如果是数字ID）
    try:
        group_id = int(group_id)
    except ValueError:
        pass
    
    if group_id in config["target_ids"]:
        config["target_ids"].remove(group_id)
        save_config(config)
        await update.message.reply_text("✅ 已删除转发目标: " + str(group_id))
    else:
        await update.message.reply_text("⚠️ 转发目标不存在")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供群组ID")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def add_watch(update, context):
“”“添加监听源”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
try:
    watch_id = context.args[0]
    config = load_config()
    
    # 尝试将输入转换为整数（如果是数字ID）
    try:
        watch_id = int(watch_id)
    except ValueError:
        pass
    
    if watch_id not in config["watch_ids"]:
        config["watch_ids"].append(watch_id)
        save_config(config)
        await update.message.reply_text("✅ 已添加监听源: " + str(watch_id))
    else:
        await update.message.reply_text("⚠️ 监听源已存在")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供群组ID或用户名")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def del_watch(update, context):
“”“删除监听源”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
try:
    watch_id = context.args[0]
    config = load_config()
    
    # 尝试将输入转换为整数（如果是数字ID）
    try:
        watch_id = int(watch_id)
    except ValueError:
        pass
    
    if watch_id in config["watch_ids"]:
        config["watch_ids"].remove(watch_id)
        save_config(config)
        await update.message.reply_text("✅ 已删除监听源: " + str(watch_id))
    else:
        await update.message.reply_text("⚠️ 监听源不存在")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供群组ID或用户名")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def show_config(update, context):
“”“显示当前配置”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
config = load_config()
text = (
    "📋 当前配置:\n\n"
    "🔑 关键词：\n" + str(config['keywords']) + "\n\n"
    "🎯 转发目标：\n" + str(config['target_ids']) + "\n\n"
    "👀 监听源群组/频道：\n" + str(config['watch_ids']) + "\n\n"
    "👤 白名单用户ID：\n" + str(config['whitelist'])
)
await update.message.reply_text(text)
```

async def allow_user(update, context):
“”“允许用户使用机器人”””
config = load_config()

```
# 只允许第一个白名单用户(管理员)添加其他用户
if update.effective_user.id != config['whitelist'][0]:
    await update.message.reply_text("❌ 权限不足")
    return

try:
    uid = int(context.args[0])
    if uid not in config["whitelist"]:
        config["whitelist"].append(uid)
        save_config(config)
        await update.message.reply_text("✅ 已允许用户: " + str(uid))
    else:
        await update.message.reply_text("⚠️ 该用户已在白名单中")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供用户ID")
except ValueError:
    await update.message.reply_text("❌ 用户ID必须为数字")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def unallow_user(update, context):
“”“移除白名单用户”””
config = load_config()

```
# 只允许第一个白名单用户(管理员)移除其他用户
if update.effective_user.id != config['whitelist'][0]:
    await update.message.reply_text("❌ 权限不足")
    return

try:
    uid = int(context.args[0])
    # 防止移除自己(第一个白名单用户)
    if uid == config['whitelist'][0]:
        await update.message.reply_text("❌ 不能移除首个白名单用户(管理员)")
        return
        
    if uid in config["whitelist"]:
        config["whitelist"].remove(uid)
        save_config(config)
        await update.message.reply_text("✅ 已移除用户: " + str(uid))
    else:
        await update.message.reply_text("⚠️ 该用户不在白名单中")
except IndexError:
    await update.message.reply_text("❌ 格式错误，请提供用户ID")
except ValueError:
    await update.message.reply_text("❌ 用户ID必须为数字")
except Exception as e:
    await update.message.reply_text("❌ 发生错误: " + str(e))
```

async def help_cmd(update, context):
“”“帮助命令”””
if not is_allowed(update.effective_user.id):
await update.message.reply_text(“❌ 权限不足”)
return

```
text = (
    "🔍 命令列表:\n\n"
    "/addkw <关键词> - 添加关键词\n"
    "/delkw <关键词> - 删除关键词\n"
    "/addgroup <群组ID> - 添加转发目标\n"
    "/delgroup <群组ID> - 删除转发目标\n"
    "/addwatch <群组ID或用户名> - 添加监听群组\n"
    "/delwatch <群组ID或用户名> - 删除监听群组\n"
    "/allow <用户ID> - 添加白名单用户（仅管理员）\n"
    "/unallow <用户ID> - 移除白名单用户（仅管理员）\n"
    "/show - 显示当前配置\n"
    "/help - 显示帮助菜单"
)
await update.message.reply_text(text)
```

async def start(update, context):
“”“启动命令”””
text = (
“👋 欢迎使用 Telegram 群组监控转发机器人!\n\n”
“此机器人可以监控指定群组或频道的消息，”
“根据关键词筛选并转发到指定目标。\n\n”
“使用 /help 查看可用命令。”
)
await update.message.reply_text(text)

def main():
try:
# 从配置文件获取机器人令牌
config = load_config()
token = config.get(‘bot_token’)

```
    if not token:
        logging.error("错误: 请在配置文件中设置有效的 bot_token")
        sys.exit(1)
    
    # 检查白名单是否为空
    if not config.get('whitelist'):
        logging.error("错误: 请在配置文件中添加至少一个白名单用户ID")
        sys.exit(1)
    
    # 创建应用
    app = ApplicationBuilder().token(token).build()
    
    # 添加命令处理程序
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("addkw", add_kw))
    app.add_handler(CommandHandler("delkw", del_kw))
    app.add_handler(CommandHandler("addgroup", add_group))
    app.add_handler(CommandHandler("delgroup", del_group))
    app.add_handler(CommandHandler("addwatch", add_watch))
    app.add_handler(CommandHandler("delwatch", del_watch))
    app.add_handler(CommandHandler("allow", allow_user))
    app.add_handler(CommandHandler("unallow", unallow_user))
    app.add_handler(CommandHandler("show", show_config))
    app.add_handler(CommandHandler("help", help_cmd))
    
    # 启动机器人
    logging.info("Bot管理器已启动")
    app.run_polling()
    
except Exception as e:
    logging.error("发生错误: " + str(e))
    sys.exit(1)
```

if **name** == ‘**main**’:
main()
EOF

# 创建示例配置文件

cat > /opt/telegram-monitor/config.example.json << ‘EOF’
{
“api_id”: “YOUR_API_ID”,
“api_hash”: “YOUR_API_HASH”,
“bot_token”: “YOUR_BOT_TOKEN”,
“target_ids”: [-1002243984935, 165067365],
“keywords”: [“example”, “keyword1”, “keyword2”],
“watch_ids”: [“channelname”, “groupname”],
“whitelist”: [123456789]
}
EOF

# 创建配置文件

cat > /opt/telegram-monitor/config.json << ‘EOF’
{
“api_id”: “123456”,
“api_hash”: “abcdef1234567890abcdef1234567890”,
“bot_token”: “1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789”,
“target_ids”: [-1001234567890],
“keywords”: [“关键词1”, “关键词2”],
“watch_ids”: [“channelname”, “groupname”],
“whitelist”: [123456789]
}
EOF

# 设置执行权限

chmod +x /opt/telegram-monitor/channel_forwarder.py
chmod +x /opt/telegram-monitor/bot_manager.py

# 创建系统服务

cat > /etc/systemd/system/channel_forwarder.service << EOF
[Unit]
Description=Telegram Channel Forwarder Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/telegram-monitor/channel_forwarder.py
WorkingDirectory=/opt/telegram-monitor
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/bot_manager.service << EOF
[Unit]
Description=Telegram Bot Manager Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/telegram-monitor/bot_manager.py
WorkingDirectory=/opt/telegram-monitor
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd

systemctl daemon-reload
systemctl enable channel_forwarder.service
systemctl enable bot_manager.service

echo “========================================”
echo “安装完成！请编辑配置文件后启动服务：”
echo “1. 编辑配置文件：nano /opt/telegram-monitor/config.json”
echo “2. 首次运行登录：cd /opt/telegram-monitor && python3 channel_forwarder.py”
echo “3. 启动服务：systemctl start channel_forwarder && systemctl start bot_manager”
echo “4. 查看状态：systemctl status channel_forwarder”
echo “========================================”
