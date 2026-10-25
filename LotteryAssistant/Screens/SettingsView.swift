import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LotteryRuleSettings.isDoubleColorBallFortunePrizeEnabled)
    private var isDoubleColorBallFortunePrizeEnabled = false

    var body: some View {
        Form {
            Section("中奖规则") {
                Toggle("启用双色球福运奖", isOn: $isDoubleColorBallFortunePrizeEnabled)
                Text("启用后，双色球恰好命中 3 个红球且未命中蓝球的单注按福运奖计 ¥5。该设置仅在后续首次核验的新票据结果中生效，已核验的历史结果不会改变。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Section("开奖数据") {
                LabeledContent("双色球主数据源", value: "中国福利彩票官网")
                LabeledContent("大乐透主数据源", value: "中国体育彩票官网")
                LabeledContent("失败兜底", value: "GitHub 开源镜像")
                Text("点击开奖中心的刷新按钮即可同步。官网接口优先提供最新号码、开奖日期和奖池数据；官网不可用时自动回退到开源历史镜像。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
            Section("同步规则") {
                Label("双色球统一使用 7 位期号；大乐透统一使用 5 位期号。", systemImage: "number.circle")
                Label("仅保存通过号码数量、范围和重复校验的开奖记录。", systemImage: "checkmark.shield")
                Label("请在开奖日 23:35 后刷新，确保奖池等数据已完整发布。", systemImage: "clock")
            }
            Section("隐私") {
                Label("票据号码和购买记录默认只保存在本机。", systemImage: "lock.fill")
                Label("照片扫描在设备本地完成，不会上传到应用服务器。", systemImage: "iphone")
            }
            Section("关于") {
                LabeledContent("版本", value: "0.2.0")
                Text("本应用不提供购彩、支付或兑奖服务；核验结果以官方当期规则为准。")
                    .foregroundStyle(AppTheme.Color.secondaryText)
            }
        }
        .navigationTitle("设置")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }
}
