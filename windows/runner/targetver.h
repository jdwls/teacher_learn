#ifndef WIN32_WINDOW_TARGET_VER_H_
#define WIN32_WINDOW_TARGET_VER_H_

// 指定目标Windows版本为Windows 7 (0x0601)
// 这确保编译时不会使用Win7不支持的API
#define _WIN32_WINNT 0x0601
#define WINVER 0x0601
#define NTDDI_VERSION 0x06010000

// 包含SDKDDKVER.h以获取正确的SDK版本定义
#include <sdkddkver.h>

#endif  // WIN32_WINDOW_TARGET_VER_H_