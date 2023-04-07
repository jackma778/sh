#!/bin/bash
echo "请输入nodeid没有的话请先私聊站长："
read new_nodeid

echo "请输入运行端口："
read new_port

echo "请确认您要将nodeid设置为$new_nodeid ,端口设置为$new_port (y/n)"
read confirm

if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
  sed -i "s/nodeId=.*/nodeId=$new_nodeid/g" .env
  sed -i "s/runPort=.*/runPort=$new_port/g" .env
  echo "修改已完成"
else
  echo "取消修改"
fi
docker-compose up -d
echo "启动完成,停止命令 docker-compose down , 启动命令 docker-compose up -d 感谢您的分享~"
