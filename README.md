# XBEchoCancellation
基于audio unit的回音消除
<br><br><br>
### 使用：
<br>
#### 获取麦克风输入：
<pre>
    XBEchoCancellation *echo = [XBEchoCancellation shared];
    echo.bl_input = ^(AudioBuffer buffer) {
        // buffer即从麦克风获取到的数据，默认已经消除了回音
    };
    [echo startInput];
</pre>
<br>
#### 播放pcm音频数据：
<pre>
    XBEchoCancellation *echo = [XBEchoCancellation shared];
    echo.bl_output = ^(AudioBuffer buffer, UInt32 inNumberFrames) {
        // 这里把要传给发声设备的pcm数据赋给buffer
    };
    [echo startOutput];
</pre>
<br>
#### 如果对你有所帮助帮忙star下