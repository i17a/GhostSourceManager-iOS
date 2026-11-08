import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("سجل العمليات والتقارير")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white)

                if vm.activityLogs.isEmpty {
                    Text("لا توجد عمليات مسجلة بعد في هذه الجلسة.")
                        .font(.system(size: 13))
                        .foregroundColor(GhostTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .ghostCard()
                } else {
                    ForEach(vm.activityLogs) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: item.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(item.isSuccess ? GhostTheme.success : GhostTheme.gold)
                                Text(item.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(item.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundColor(GhostTheme.textSecondary)
                            }
                            Text(item.detail)
                                .font(.system(size: 12))
                                .foregroundColor(GhostTheme.textSecondary)
                        }
                        .padding(14)
                        .ghostCard()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
