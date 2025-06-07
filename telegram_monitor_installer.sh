#!/usr/bin/env python3
“””
Telegram 消息监控转发工具 - 单文件版
监控指定群组/频道的消息，匹配关键词后转发到目标，并添加来源和时间信息
“””

from telethon import TelegramClient, events
from datetime import datetime
import asyncio
import logging
import sys

# 配置日志

logging.basicConfig(format=’%(asctime)s - %(levelname)s - %(message)s’, level=logging.INFO)
logger = logging.getLogger(**name**)

# ============ 配置区域 - 使用前请修改 ============

# Telegram API 信息 - 从 https://my.telegram.org/apps 获取

API_ID = “123456”           # 替换为您的 API ID
API_HASH = “abcdef1234567890abcdef” # 替换为您的 API Hash

# 监控和转发配置

KEYWORDS = [“关键词1”, “关键词2”]  # 要监控的关键词
WATCH_IDS = [“频道用户名”, “群组ID”]  # 要监控的群组/频道
TARGET_IDS = [-1001234567890]  # 转发目标ID

# ==============================================

# 创建客户端实例

client = TelegramClient(‘telegram_monitor_session’, API_ID, API_HASH)

@client.on(events.NewMessage)
async def message_handler(event):
“”“处理新消息事件”””
# 获取消息文本
msg = event.message.message
if not msg:
return

```
# 获取来源信息
try:
    from_entity = await event.get_chat()
    from_chat = getattr(from_entity, 'username', None) or str(event.chat_id)
except Exception as e:
    logger.error(f"获取来源信息失败: {e}")
    from_chat = str(event.chat_id)

# 检查是否为监控目标
if from_chat not in WATCH_IDS and str(event.chat_id) not in WATCH_IDS:
    return

# 检查关键词
for keyword in KEYWORDS:
    if keyword.lower() in msg.lower():
        # 获取当前时间
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        logger.info(f"命中关键词: {keyword}")
        logger.info(f"来源: {from_chat}")
        logger.info(f"消息内容: {msg[:100]}...")  # 只显示消息前100个字符
        
        # 准备添加来源和时间的前缀信息
        source_info = f"来源群组: {from_chat}\n时间: {current_time}\n\n"
        
        # 转发到所有目标
        for target in TARGET_IDS:
            try:
                # 创建新消息，添加来源信息，同时保留原始消息内容
                await client.send_message(target, source_info + msg)
                logger.info(f"成功转发到 {target}")
            except Exception as e:
                logger.error(f"转发到 {target} 失败: {e}")
        break  # 匹配一个关键词就跳出循环
```

async def main():
“”“主函数”””
# 连接到 Telegram
await client.start()

```
# 显示当前配置信息
me = await client.get_me()
logger.info(f"已登录账号: {me.first_name} (@{me.username})")
logger.info(f"监控关键词: {KEYWORDS}")
logger.info(f"监控来源: {WATCH_IDS}")
logger.info(f"转发目标: {TARGET_IDS}")

logger.info("监控服务已启动，按 Ctrl+C 停止")

# 保持运行
await client.run_until_disconnected()
```

if **name** == “**main**”:
try:
asyncio.run(main())
except KeyboardInterrupt:
logger.info(“服务已停止”)
sys.exit(0)
except Exception as e:
logger.error(f”发生错误: {e}”)
sys.exit(1)
