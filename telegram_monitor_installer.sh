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
print(f”错误: 未找到配置文件 {CONFIG_FILE}”)
print(“请从 config.example.json 复制一份并填写相关信息”)
sys.exit(1)
except json.JSONDecodeError:
print(f”错误: 配置文件 {CONFIG_FILE} 格式不正确”)
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

async def get_chat_info(chat):
“”“获取群组/频道的详细信息”””
chat_info = {
‘id’: chat.id,
‘title’: getattr(chat, ‘title’, ‘’),
‘username’: getattr(chat, ‘username’, ‘’),
‘type’: ‘unknown’
}

```
# 判断聊天类型
if hasattr(chat, 'megagroup') and chat.megagroup:
    chat_info['type'] = '超级群组'
elif hasattr(chat, 'broadcast') and chat.broadcast:
    chat_info['type'] = '频道'
elif hasattr(chat, 'gigagroup') and chat.gigagroup:
    chat_info['type'] = '广播群组'
elif getattr(chat, 'username', None):
    chat_info['type'] = '群组/频道'
else:
    chat_info['type'] = '私聊群组'

return chat_info
```

@client.on(events.NewMessage)
async def handler(event):
# 每次处理消息时重新加载配置，以便实时更新关键词等
config = load_config()

```
# 获取消息文本
msg = event.message.message
if not msg:
    return

# 获取聊天信息
chat = await event.get_chat()
chat_info = await get_chat_info(chat)

# 构建来源标识
source_identifier = chat_info['username'] or str(chat_info['id'])

# 检查是否为监控目标
if source_identifier not in config["watch_ids"] and str(chat_info['id']) not in config["watch_ids"]:
    return

# 检查关键词
matched_keyword = None
for keyword in config["keywords"]:
    if keyword.lower() in msg.lower():
        matched_keyword = keyword
        break

if matched_keyword:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 命中关键词: {matched_keyword}")
    print(f"来源: {chat_info['title']} ({source_identifier}) - {chat_info['type']}")
    print(f"消息内容: {msg[:100]}...")  # 只显示消息前100个字符
    
    # 构建带来源信息的转发消息
    source_info = f"📍 来源: {chat_info['title'] or '未知群组'}"
    if chat_info['username']:
        source_info += f" (@{chat_info['username']})"
    source_info += f"\n🏷️ 类型: {chat_info['type']}"
    source_info += f"\n🔑 触发关键词: {matched_keyword}"
    source_info += f"\n⏰ 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    source_info += f"\n{'='*40}"
    
    # 转发到所有目标
    for target in config["target_ids"]:
        try:
            # 先发送来源信息
            await client.send_message(target, source_info)
            
            # 然后转发原消息
            await client.forward_messages(target, event.message)
            
            print(f"✅ 成功转发到 {target} (包含来源信息)")
        except Exception as e:
            print(f"❌ 转发到 {target} 失败: {e}")
```

print(”>>> 正在监听关键词转发 (增强版 - 包含来源信息) …”)
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
print(f”发生错误: {e}”)
sys.exit(1)
