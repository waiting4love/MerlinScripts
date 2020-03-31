# Asuswrt-Merlin 脚本

个人使用的路由器（RT-AC86U）脚本, 基于官方梅林固件384.15版

## 内网专用域名

本人内网的192.168.2.8是一个小服务器, 通过反向代理和docker实现了几个服务, 用域名区分. 在内网直接输入域名即可进入对应服务.

路由器设置: `/jffs/configs/dnsmasq.conf.add`, 加入:

`address=/kodex.lan/git.lan/aria.lan/192.168.2.8`

## 设置虚拟内存

最简单的就是直接运行梅林自带的`amtm`命令设置虚拟内存, 如果喜欢折腾, 继续往下看

如果要自己手动建立的话, 输入下列命令(sda1是U盘, 大小是bs*count, 这里总共是1G):

```sh
dd if=/dev/zero of=/tmp/mnt/sda1/swapfile bs=1024 count=1048576
mkswap /tmp/mnt/sda1/swapfile
swapon /tmp/mnt/sda1/swapfile
```

然后在`/jffs/scripts/post-mount`中输入

```sh
if [ -f "$1/swapfile" ]; then
swapon "$1/swapfile"
fi
```

## 用U盘文件夹代替JFFS分区

主要代码:`/jffs/scripts/jffs2u.sh` 

逻辑是查找U盘上有没有jffs文件夹，如果存在，就把当前`/jffs`里的文件复制到这个文件夹， 然后把它mount到`/jffs`代替原来的JFFS分区。

代码是从这里拿来的: https://www.snbforums.com/threads/jffs-usb-offloading.24884, 感谢大神

原代码在我的RT-AC86U 384.15版固件上有一点小问题，`jffs`区找不对，所以改了一小点。另外添加了几行代码用于清空缓存，因为执行完这个脚本后内存就占得差不多了，虽然关系不大但是影响心情。

```sh
sleep 3
sync
sleep 1
echo 3 > /proc/sys/vm/drop_caches
cru a FreeMem 0 6 * * * "echo 3 > /proc/sys/vm/drop_caches"
```

在`/jffs/scripts/post-mount`中调用:

```sh
# load jffs to USB
/jffs/scripts/jffs2u.sh $1
```

然后做个名为`unmount`的符号链接, 负责把U盘上修改的脚本与配置同步回JFFS分区

```sh
ln -s /jffs/scripts/jffs2u.sh /jffs/scripts/unmount
```

## Samba不共享没权限的文件夹

主要代码: `/jffs/scripts/dontShareOther.sh`，看这文件名，再看里面风骚的注释就知道是本人写的

功能：华硕路由器的Samba共享只能设置权限，却总是把所有的文件夹全部共享在网络中。

![](https://github.com/waiting4love/MerlinScripts/raw/master/Snipaste_2020-03-31_21-59-39.png)

用了这个脚本后，完全没有权限的文件夹就不会共享出来了：

![](https://github.com/waiting4love/MerlinScripts/raw/master/Snipaste_2020-03-31_22-01-13.png)

### 使用方式

在`/jffs/scripts/smb.postconf`中加入下面的代码来调用`dontShareOther.sh`

```sh
CONFIG="$1"

/jffs/scripts/dontShareOther.sh < "$CONFIG" > /tmp/smb2.conf
cp /tmp/smb2.conf "$CONFIG"
rm /tmp/smb2.conf
```

实现逻辑: `smb.postconf`会在`/etc/smb.conf`创建时被调用（并且把`/etc/smb.conf`作为参数），这时遍历`/etc/smb.conf`中的配置把完全没有权限的共享项目移除即可。