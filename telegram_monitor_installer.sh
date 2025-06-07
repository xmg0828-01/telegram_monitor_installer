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
        
        print(f"[{current_time}] 命中关键词: {keyword}")
        print(f"来源: {from_chat}")
        print(f"消息内容: {msg[:100]}...")  # 只显示消息前100个字符
        
        # 准备添加来源和时间的前缀信息
        source_info = f"来源群组: {from_chat}\n时间: {current_time}\n\n"
        
        # 转发到所有目标
        for target in config["target_ids"]:
            try:
                # 创建新消息，添加来源信息，同时保留原始消息内容
                await client.send_message(target, source_info + msg)
                print(f"✅ 成功转发到 {target}")
            except Exception as e:
                print(f"❌ 转发到 {target} 失败: {e}")
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
print(f”发生错误: {e}”)
sys.exit(1)
