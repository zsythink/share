#!/bin/bash

#脚本作用：根据镜像中RooFS的diffID计算出对应的chainID以及cacheID
#运行脚本前请安装jq命令，确保系统中有sha256sum命令，此脚本中的默认路径均针对overlay2存储驱动设置。

set -e

if [[ -z $1 ]];then
    echo "usage: ./layerID.sh REPOSITORY:TAG" && exit 88
fi

imageName=$1

#通过inspect命令获取到镜像信息，通过jq命令获取其中的RootFS段落中的layers哈希
diffIdList=`docker inspect $1 | jq -r ".[0].RootFS.Layers | .[]"`

#输出获取到的diffID
echo "$diffIdList"

#输出各种ID对应的信息在哪些目录中可以查看
echo "###########"
echo "diffID"
echo "/var/lib/docker/image/overlay2/distribution"
echo "###########"

echo "###########"
echo "chainID"
echo "/var/lib/docker/image/overlay2/layerdb/sha256/<chainID>"
echo "###########"

echo "###########"
echo "cacheID"
echo "/var/lib/docker/overlay2/<cacheID>"
echo "###########"

#通过diffID，计算出chainID，输出对应cacheID，并输出
preChainId="0"
firstLayerDiffID=`docker inspect $1 | jq -r ".[0].RootFS.Layers | .[0]"`
for i in `echo "$diffIdList"`;do
    #如果是最底层（RootFS列表中的第一个为最底层），chainID=diffID
    if [ "$i" == "$firstLayerDiffID" ];then
        echo "diffID" "$i"
        echo "chainID" "$i"
        echo "cacheID" "$(cat /var/lib/docker/image/overlay2/layerdb/sha256/`echo -n $i | awk -F: '{print $2}'`/cache-id)"
        preChainId=`echo -n "$i"`
    fi
    #如果不是最底层，当前层的chainID等于sha256(上一层的chainID+空格+当前层的diffID)，也就是两个ID中间用空格连接后取sha256的哈希值，计算ID时，需要有sha256:前缀，并且不能有换行符
    if [ "$i" != "$firstLayerDiffID" ];then
        chainId=`echo -n "$preChainId $i" | sha256sum | awk '{print $1}'`
        currentChainId="sha256:$chainId"
        echo "diffID" "$i"
        echo "chainID" "$currentChainId"
        echo "cacheID" "$(cat /var/lib/docker/image/overlay2/layerdb/sha256/${chainId}/cache-id)"
        preChainId=$currentChainId
    fi
    echo "###########"
done
