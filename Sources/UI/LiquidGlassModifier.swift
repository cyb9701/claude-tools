import SwiftUI

extension View {

    /// 카드 형태의 glass 배경 적용.
    ///
    /// macOS 26+에서는 Liquid Glass material을 적용하고,
    /// 이전 버전에서는 ultraThinMaterial 배경으로 폴백하여 시각적 일관성을 유지한다.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// 작은 chip 컴포넌트에 glass 효과 적용.
    ///
    /// codeMetrics 섹션의 토큰/비용/세션 chip에 사용된다.
    /// 개별 chip은 독립된 glass pill로 렌더링된다.
    @ViewBuilder
    func glassChip() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: 7))
        } else {
            self.background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}
