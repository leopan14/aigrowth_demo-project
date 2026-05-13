#!/bin/bash
# 一键发布产品方案到公网（trycloudflare 临时链接，24h 内有效）
# 用法：bash share.sh
# 停止：Ctrl+C

set -e
cd "$(dirname "$0")"

PORT=8765
LOG=/tmp/share-tunnel.log
PIDS=()

cleanup() {
  echo ""
  echo "🧹 清理中..."
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
  lsof -ti :$PORT 2>/dev/null | xargs kill 2>/dev/null || true
  echo "✅ 已停止"
}
trap cleanup EXIT INT TERM

# 端口冲突检测
if lsof -i :$PORT >/dev/null 2>&1; then
  echo "❌ 端口 $PORT 被占用，请先释放或改本脚本里的 PORT 变量"
  exit 1
fi

echo "▶ 启动本地 HTTP server (端口 $PORT)..."
python3 -m http.server $PORT >/dev/null 2>&1 &
PIDS+=($!)
sleep 1

echo "▶ 启动 cloudflared 临时隧道..."
# --config /dev/null 跳过你已有的 named tunnel 配置，强制走 quick tunnel
cloudflared tunnel --url http://localhost:$PORT --config /dev/null --no-autoupdate > "$LOG" 2>&1 &
PIDS+=($!)

echo "⏳ 等待隧道建立..."
URL=""
for i in {1..30}; do
  sleep 1
  URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | head -1)
  if [ -n "$URL" ]; then break; fi
done

if [ -z "$URL" ]; then
  echo "❌ 隧道建立失败，查看日志：$LOG"
  exit 1
fi

# 等 cloudflared 边缘节点真正就绪
sleep 4
STATUS=$(curl -sL -o /dev/null -w "%{http_code}" "$URL/" --max-time 10)

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ 你的在线链接已就绪（HTTP $STATUS）"
echo ""
echo "  🔗 $URL"
echo ""
echo "  📄 直接打开看 10 页幻灯片：$URL"
echo "  📄 Markdown 原文：$URL/产品方案_数字组织与员工管理_V1.md"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  这是匿名公网链接，任何人拿到都能看，不要随意外发"
echo "⏸  保持本窗口开着；Ctrl+C 即可立即断链"
echo ""

wait
