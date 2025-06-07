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
        print("请从 config.example.json 复制一份并填写相关信息")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"错误: 配置文件 {CONFIG_FILE} 格式不正确")
        sys.exit(1)

# 加载配置
config = load_config()

# 从配置文件获取API凭据
api_id = config.get('api_id')
api_hash = config.get('api_hash')

if not api_id or not api_hash:
    print("错误: 请在配置文件中设置有效的 api_id 和 api_hash")
    print("您可以从 https://my.telegram.org/apps 获取这些信息")
    sys.exit(1)

# 创建客户端实例
client = TelegramClient('channel_forward_session', api_id, api_hash)

@client.on(events.NewMessage)
async def handler(event):
    # 每次处理消息时重新加载配置，以便实时更新关键词等
    config = load_config()
    
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
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 命中关键词: {keyword}")
            print(f"来源: {from_chat}")
            print(f"消息内容: {msg[:100]}...")  # 只显示消息前100个字符
            
            # 获取详细的来源信息
            try:
                chat_entity = await client.get_entity(event.chat_id)
                
                # 构建来源信息
                if hasattr(chat_entity, 'username') and chat_entity.username:
                    source_info = f"@{chat_entity.username}"
                    if hasattr(chat_entity, 'title'):
                        source_info += f" ({chat_entity.title})"
                elif hasattr(chat_entity, 'title'):
                    source_info = chat_entity.title
                else:
                    source_info = f"群组ID: {event.chat_id}"
                
                # 获取发送者信息
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
                
                # 构建带来源信息的消息
                source_header = f"📢 消息来源: {source_info}"
                if sender_info:
                    source_header += f"\n👤 发送者: {sender_info}"
                source_header += f"\n🕐 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                source_header += f"\n🔑 匹配关键词: {keyword}"
                source_header += "\n" + "─" * 30 + "\n"
                
                # 转发到所有目标
                for target in config["target_ids"]:
                    try:
                        # 先发送来源信息
                        await client.send_message(target, source_header)
                        # 再转发原始消息
                        await client.forward_messages(target, event.message)
                        print(f"✅ 成功转发到 {target} (包含来源信息)")
                    except Exception as e:
                        print(f"❌ 转发到 {target} 失败: {e}")
                        
            except Exception as e:
                print(f"❌ 获取来源信息失败: {e}")
                # 如果获取详细信息失败，使用简单的来源信息
                simple_source = f"📢 消息来源: {from_chat}\n🕐 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n🔑 匹配关键词: {keyword}\n" + "─" * 30 + "\n"
                
                for target in config["target_ids"]:
                    try:
                        await client.send_message(target, simple_source)
                        await client.forward_messages(target, event.message)
                        print(f"✅ 成功转发到 {target} (简单来源信息)")
                    except Exception as e:
                        print(f"❌ 转发到 {target} 失败: {e}")
            
            break  # 匹配一个关键词就跳出循环

print(">>> 正在监听关键词转发 ...")
print(">>> 如果是首次运行，请按照提示完成 Telegram 登录")
print(">>> 按 Ctrl+C 可停止运行")

if __name__ == "__main__":
    try:
        client.start()
        client.run_until_disconnected()
    except KeyboardInterrupt:
        print("\n程序已停止")
        sys.exit(0)
    except Exception as e:
        print(f"发生错误: {e}")
        sys.exit(1)
