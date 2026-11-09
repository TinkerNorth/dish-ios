// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// Settings › About › Open source licenses: the third-party notice the app
/// ships with, read by the scene, then Dish's own licence and version.
struct LicensesPage: View {
    @Environment(\.thirdPartyNotice) private var notice
    @Environment(\.appVersion) private var appVersion

    var body: some View {
        LicensesPageBody(state: licensesPageState(notice: notice, appVersion: appVersion))
    }
}

/// The page over its state, so a preview can draw it.
struct LicensesPageBody: View {
    let state: LicensesPageState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DishSpace.s5) {
                switch state.content {
                case let .missing(title, body):
                    ContentUnavailableView(title, systemImage: "doc.text", description: Text(body))
                case let .notice(blocks):
                    ForEach(blocks) { LicenseBlockView(block: $0.block) }
                }
                Divider()
                Text(state.licence).font(DishFont.detail).foregroundStyle(DishTheme.onSurface)
                Text(state.versionLine).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DishSpace.page)
        }
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseBlockView: View {
    let block: LicenseBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(text)
                .font(licenseHeadingFont(level))
                .foregroundStyle(DishTheme.onSurface)
                .padding(.top, DishSpace.s4)
        case let .paragraph(text):
            Text(text)
                .font(DishFont.detail)
                .foregroundStyle(DishTheme.onSurface)
                .fixedSize(horizontal: false, vertical: true)
        case let .code(text):
            Text(text)
                .font(DishFont.monoDetail)
                .foregroundStyle(DishTheme.muted)
                .padding(DishSpace.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DishTheme.surface, in: RoundedRectangle(cornerRadius: DishSize.codeCorner, style: .continuous))
        case let .row(cells, header):
            LicenseRow(cells: cells, header: header)
        case .rule:
            Divider()
        }
    }
}

/// A table row of the notice, its cells side by side.
private struct LicenseRow: View {
    let cells: [AttributedString]
    let header: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DishSpace.s4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { cell in
                Text(cell.element)
                    .font(licenseCellFont(header: header))
                    .foregroundStyle(licenseCellColor(header: header))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Licenses") {
    let notice = """
    # Third-party notices

    Dish for iOS is licensed LGPL-3.0-or-later.

    | Component | SPDX |
    |---|---|
    | SwiftLint | `MIT` |
    """
    NavigationStack {
        LicensesPageBody(state: licensesPageState(notice: notice, appVersion: "0.1.0"))
    }
}

#Preview("Missing") {
    NavigationStack {
        LicensesPageBody(state: licensesPageState(notice: nil, appVersion: "0.1.0"))
    }
}
