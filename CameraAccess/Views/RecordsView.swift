/*
 * Records View
 * 记录页面 - 包含各类记录的 Tab
 */

import SwiftUI

struct RecordsView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.lg) {
                        RecordTabButton(title: "Live AI", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }

                        RecordTabButton(title: "实时翻译", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }

                        RecordTabButton(title: NSLocalizedString("records.movie.title", comment: "Walk Into Movie records"), isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                }
                .background(AppColors.tertiaryBackground)

                // Content (disable swipe paging to allow list swipe actions)
                Group {
                    switch selectedTab {
                    case 0:
                        LiveAIRecordsView()
                    case 1:
                        TranslationRecordsView()
                    case 2:
                        WalkIntoMovieRecordsView()
                    default:
                        WalkIntoMovieRecordsView()
                    }
                }
            }
            .navigationTitle("记录")
        }
    }
}

// MARK: - Record Tab Button

struct RecordTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)

                if isSelected {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .cornerRadius(1.5)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                }
            }
        }
    }
}

// MARK: - Live AI Records

struct LiveAIRecordsView: View {
    @StateObject private var viewModel = ConversationListViewModel(categoryFilter: .liveAI)
    @State private var selectedConversation: ConversationRecord?

    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            if viewModel.conversations.isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.liveAI.opacity(0.6))

                    Text("暂无 Live AI 对话记录")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)

                    Text("使用 Live AI 功能后记录将显示在这里")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
            } else {
                List {
                    ForEach(viewModel.conversations) { conversation in
                        ConversationCell(
                            conversation: conversation,
                            iconName: "brain.head.profile",
                            accentColor: AppColors.liveAI
                        )
                            .listRowInsets(
                                EdgeInsets(
                                    top: AppSpacing.sm,
                                    leading: AppSpacing.md,
                                    bottom: AppSpacing.sm,
                                    trailing: AppSpacing.md
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedConversation = conversation
                            }
                    }
                    .onDelete(perform: deleteConversations)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColors.secondaryBackground)
                .refreshable {
                    viewModel.loadConversations()
                }
            }
        }
        .onAppear {
            viewModel.loadConversations()
        }
        .sheet(item: $selectedConversation) { conversation in
            ConversationDetailView(conversation: conversation)
        }
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = viewModel.conversations[index]
            viewModel.deleteConversation(conversation.id)
        }
    }
}

// MARK: - Translation Records

struct TranslationRecordsView: View {
    @StateObject private var viewModel = ConversationListViewModel(categoryFilter: .liveTranslate)
    @State private var selectedConversation: ConversationRecord?

    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            if viewModel.conversations.isEmpty {
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.translate.opacity(0.6))

                    Text("暂无实时翻译记录")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)

                    Text("使用实时翻译后记录将显示在这里")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
            } else {
                List {
                    ForEach(viewModel.conversations) { conversation in
                        ConversationCell(
                            conversation: conversation,
                            iconName: "text.bubble",
                            accentColor: AppColors.translate
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: AppSpacing.sm,
                                leading: AppSpacing.md,
                                bottom: AppSpacing.sm,
                                trailing: AppSpacing.md
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConversation = conversation
                        }
                    }
                    .onDelete(perform: deleteConversations)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppColors.secondaryBackground)
                .refreshable {
                    viewModel.loadConversations()
                }
            }
        }
        .onAppear {
            viewModel.loadConversations()
        }
        .sheet(item: $selectedConversation) { conversation in
            ConversationDetailView(conversation: conversation)
        }
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = viewModel.conversations[index]
            viewModel.deleteConversation(conversation.id)
        }
    }
}

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [ConversationRecord] = []
    private let categoryFilter: ConversationCategory?

    init(categoryFilter: ConversationCategory? = nil) {
        self.categoryFilter = categoryFilter
    }

    func loadConversations() {
        var records = ConversationStorage.shared.loadAllConversations()
        if let categoryFilter {
            records = records.filter { $0.category == categoryFilter }
        }
        conversations = records
        print("📱 [RecordsView] 加载对话: \(conversations.count) 条")
    }

    func deleteConversation(_ id: UUID) {
        ConversationStorage.shared.deleteConversation(id)
        loadConversations()
    }
}

// MARK: - Conversation Cell

struct ConversationCell: View {
    let conversation: ConversationRecord
    let iconName: String
    let accentColor: Color

    init(
        conversation: ConversationRecord,
        iconName: String = "brain.head.profile",
        accentColor: Color = AppColors.liveAI
    ) {
        self.conversation = conversation
        self.iconName = iconName
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(accentColor)
                    .font(AppTypography.headline)

                Text(conversation.title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            // Summary
            if !conversation.summary.isEmpty {
                Text(conversation.summary)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            // Footer
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock")
                        .font(AppTypography.caption)
                    Text(conversation.formattedDate)
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(AppTypography.caption)
                    Text("\(conversation.messageCount) 条消息")
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.textSecondary)

                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(AppCornerRadius.lg)
        .shadow(color: AppShadow.small(), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Walk Into Movie Records

struct WalkIntoMovieRecordsView: View {
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "film")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.walkIntoMovie.opacity(0.6))

                Text(NSLocalizedString("records.movie.empty.title", comment: "No movie records title"))
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text(NSLocalizedString("records.movie.empty.subtitle", comment: "No movie records subtitle"))
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
