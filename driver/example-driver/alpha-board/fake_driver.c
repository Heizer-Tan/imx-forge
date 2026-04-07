// Fake驱动示例 - 仅用于验证构建工具链
//
// 这是一个不实际驱动任何硬件的虚拟驱动，用来验证：
// 1. 构建系统是否正常工作
// 2. 部署脚本是否正确
// 3. 驱动加载/卸载流程是否正常
//
// 用法：
//   insmod fake_driver.ko    # 加载驱动
//   rmmod fake_driver        # 卸载驱动
//   dmesg | tail             # 查看日志

#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>

// 模块参数
static int test_value = 42;
module_param(test_value, int, 0644);
MODULE_PARM_DESC(test_value, "测试参数");

// 模块初始化
static int __init fake_init(void)
{
	pr_info("=== Fake驱动加载成功 ===\n");
	pr_info("测试参数值: %d\n", test_value);
	pr_info("这是一个验证构建工具链的虚拟驱动\n");
	pr_info("不实际驱动任何硬件\n");
	pr_info("========================\n");
	return 0;
}

// 模块退出
static void __exit fake_exit(void)
{
	pr_info("=== Fake驱动卸载成功 ===\n");
	pr_info("工具链验证完成！\n");
	pr_info("========================\n");
}

module_init(fake_init);
module_exit(fake_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("IMX-Forge Framework");
MODULE_DESCRIPTION("Fake驱动 - 仅用于验证构建工具链");
MODULE_VERSION("1.0");
