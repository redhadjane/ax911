import SwiftUI

struct InboxHubView: View {
    @EnvironmentObject private var store: HOPStore
    @EnvironmentObject private var chat: HOPMessages
    var body: some View {
        VStack(spacing: 0) {
            Picker("Inbox section", selection: $store.inboxSection) {
                Text(chat.unread > 0 ? "Messages (\(chat.unread))" : "Messages").tag("messages")
                Text(store.unread > 0 ? "Alerts (\(store.unread))" : "Alerts").tag("alerts")
            }.pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 12)
            if store.inboxSection == "messages" { ConversationListView() }
            else { NotificationsView() }
        }.background(HOPStyle.background).navigationTitle("Inbox")
            .navigationDestination(item: $store.messageThreadID) { id in ChatThreadView(conversationID: id) }
    }
}

struct ConversationListView: View {
    @EnvironmentObject private var store: HOPStore
    @EnvironmentObject private var chat: HOPMessages
    @State private var search = ""
    @State private var unreadOnly = false
    @State private var compose = false
    @State private var reports = false
    private var rows: [HOPConversation] { chat.conversations.filter { $0.matches(search) && (!unreadOnly || $0.unread > 0) } }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("YOUR TEAM, CONNECTED", systemImage: "bubble.left.and.bubble.right.fill").font(.caption.weight(.semibold)).foregroundStyle(HOPStyle.green)
                    Text("Work conversations.\nNot personal phone numbers.").font(.title2.bold())
                    Text("Private chats are visible only to their participants. Team groups follow your current roles.").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
                Toggle("Unread only", isOn: $unreadOnly)
            }
            if let error = chat.error { Section { MessageErrorView(message: error) { Task { await chat.loadSession(force: true); await chat.refreshSummary() } } } }
            if chat.loading && chat.conversations.isEmpty { ProgressView("Loading conversations…") }
            else if rows.isEmpty { HOPEmpty(title: unreadOnly ? "You're caught up" : "No matching conversations", detail: unreadOnly ? "Unread team messages will appear here." : "Try another search or start a new chat.", icon: "bubble.left.and.bubble.right") }
            Section("Conversations") {
                ForEach(rows) { conversation in
                    Button { store.messageThreadID = conversation.id; HOPStyle.haptic() } label: { ConversationRow(conversation: conversation) }.buttonStyle(.plain).padding(.vertical, 4)
                }
            }
            Section {
                Text("Mute pauses a conversation's push alerts. Blocking stops direct messages in both directions; essential team-group messages remain available.").font(.caption).foregroundStyle(.secondary)
                Text("This SideStore build checks messages while HOP is open. Background server push needs a separately provisioned APNs build; it is not enabled here.").font(.caption).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).background(HOPStyle.background)
            .searchable(text: $search, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("New chat", systemImage: "square.and.pencil") { compose = true }.accessibilityLabel("Start a private chat") }
                if chat.isManager { ToolbarItem(placement: .topBarTrailing) { Button("Reports", systemImage: "flag") { reports = true } } }
            }
            .task { await chat.loadSession(); await chat.refreshSummary() }
            .refreshable { await chat.loadSession(force: true); await chat.refreshSummary() }
            .sheet(isPresented: $compose) { NavigationStack { NewChatView() } }
            .sheet(isPresented: $reports) { NavigationStack { MessageReportsView() } }
    }
}

struct ConversationRow: View {
    let conversation: HOPConversation
    var body: some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 16).fill(HOPStyle.green.opacity(0.10)); Text(conversation.initial.uppercased()).font(.headline).foregroundStyle(HOPStyle.green) }.frame(width: 48, height: 48).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) { Text(conversation.title).font(.headline); if conversation.muted { Image(systemName: "bell.slash").font(.caption).foregroundStyle(.secondary) } }
                Text(verbatim: conversation.lastBody.isEmpty ? (conversation.managerOnly ? "Updates from managers" : conversation.isDirect ? "Private conversation" : "Your team's workspace") : conversation.lastBody).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 6)
            if conversation.unread > 0 { Text(conversation.unread > 99 ? "99+" : String(conversation.unread)).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 5).foregroundStyle(Color.white).background(HOPStyle.hero, in: Capsule()).accessibilityLabel("\(conversation.unread) unread messages") }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
        }.contentShape(Rectangle()).frame(minHeight: 60)
    }
}

struct MessageErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 10) { Label(message, systemImage: "wifi.exclamationmark").font(.subheadline).foregroundStyle(.red); Button("Try again", action: retry).frame(minHeight: 44) } }
}

struct NewChatView: View {
    @EnvironmentObject private var store: HOPStore
    @EnvironmentObject private var chat: HOPMessages
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var people: [HOPRecord] { chat.people.filter { $0.id != chat.employeeID && (search.isEmpty || ($0.name + $0["role"].text).localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        List {
            Section { Text("Choose a teammate. Your chat is private to the two participants; personal phone numbers are not shared.").font(.subheadline).foregroundStyle(.secondary) }
            if let error = chat.error { MessageErrorView(message: error) { Task { await chat.loadSession(force: true) } } }
            ForEach(people) { person in
                Button { Task { if let id = await chat.direct(to: person.id) { store.messageThreadID = id; dismiss() } } } label: {
                    HStack(spacing: 12) {
                        Text(String(person.name.prefix(1)).uppercased()).font(.headline).foregroundStyle(HOPStyle.green).frame(width: 44, height: 44).background(HOPStyle.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) { Text(person.name).font(.headline); Text((person["role"].text == "waitress" ? "Server" : person["role"].text.capitalized) + (chat.blockedIDs.contains(person.id) ? " · blocked" : "")).font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "bubble.left").foregroundStyle(HOPStyle.green)
                    }.padding(.vertical, 5)
                }.buttonStyle(.plain).disabled(chat.actionBusy)
            }
            if people.isEmpty { Text("No teammates match your search.").foregroundStyle(.secondary) }
        }.navigationTitle("New chat").searchable(text: $search, prompt: "Name or role")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
            .task { await chat.loadSession(force: true) }
    }
}

struct ChatThreadView: View {
    let conversationID: String
    @EnvironmentObject private var chat: HOPMessages
    @Environment(\.scenePhase) private var phase
    @State private var report: HOPChatMessage?
    @State private var confirmBlock = false
    @State private var followLatest = true
    private var title: String { chat.conversations.first { $0.id == conversationID }?.title ?? "Conversation" }
    private var draft: Binding<String> { Binding(get: { chat.drafts[conversationID]?.text ?? "" }, set: { chat.setDraft($0, for: conversationID) }) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) { Image(systemName: chat.detail?.kind == "direct" ? "lock" : "person.3"); Text(chat.detail?.kind == "direct" ? "Private · only the two participants" : "Team group · current role access"); if chat.detail?.muted == true { Image(systemName: "bell.slash") } }.font(.caption).foregroundStyle(.secondary).padding(12).frame(maxWidth: .infinity).background(HOPStyle.paper)
            if let error = chat.error { MessageErrorView(message: error) { Task { await chat.refreshThread() } }.padding(.horizontal, 16).padding(.top, 8) }
            history
            composer
        }.background(HOPStyle.background).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let detail = chat.detail {
                            Button(detail.muted ? "Unmute conversation" : "Mute conversation", systemImage: detail.muted ? "bell" : "bell.slash") { Task { await chat.mute(conversationID, muted: !detail.muted) } }
                            if detail.kind == "direct", !detail.peerID.isEmpty { Button(detail.blockedByMe ? "Unblock teammate" : "Block direct messages", systemImage: "hand.raised", role: detail.blockedByMe ? nil : .destructive) { confirmBlock = true } }
                        }
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await chat.refreshThread() } }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("Conversation actions").disabled(chat.actionBusy)
                }
            }
            .confirmationDialog(chat.detail?.blockedByMe == true ? "Unblock this teammate?" : "Block direct messages?", isPresented: $confirmBlock, titleVisibility: .visible) {
                if let detail = chat.detail { Button(detail.blockedByMe ? "Unblock" : "Block", role: detail.blockedByMe ? nil : .destructive) { Task { await chat.block(detail.peerID, blocked: !detail.blockedByMe) } } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Blocking stops direct messages in both directions. Existing messages are retained, and team-group messages stay visible.") }
            .sheet(item: $report) { message in NavigationStack { ReportMessageView(message: message) } }
            .task(id: "\(conversationID)|\(phase)|\(chat.employeeID)") {
                guard phase == .active else { return }; await chat.open(conversationID)
                while !Task.isCancelled { try? await Task.sleep(for: .seconds(10)); guard !Task.isCancelled else { return }; await chat.refreshThread() }
            }
            .onDisappear { chat.close(conversationID) }
    }
    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if chat.hasMore { Button { Task { await chat.loadEarlier() } } label: { if chat.loadingOlder { ProgressView() } else { Text("Load earlier messages") } }.frame(minHeight: 44).disabled(chat.loadingOlder) }
                    if chat.messages.isEmpty { if chat.loadingThread { ProgressView("Loading conversation…").padding(30) } else { HOPEmpty(title: "Start the conversation", detail: "Keep the team in the loop. Work messages stay here, not in personal texts.", icon: "bubble.left.and.bubble.right") } }
                    ForEach(chat.messages) { message in
                        ChatBubble(message: message, own: message.senderID == chat.employeeID, read: message.isRead(by: chat.detail?.peerReadSequence))
                            .id(message.id)
                            .contextMenu { if message.senderID != chat.employeeID { Button("Report message", systemImage: "flag") { report = message } } }
                    }
                    Color.clear.frame(height: 1).id("message-bottom").onAppear { followLatest = true }.onDisappear { followLatest = false }
                }.padding(16)
            }.scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.messages.last?.id) { _, _ in if followLatest { proxy.scrollTo("message-bottom", anchor: .bottom) } }
                .onChange(of: chat.sending) { was, sending in if was && !sending && chat.error == nil { followLatest = true; proxy.scrollTo("message-bottom", anchor: .bottom) } }
        }
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if chat.detail?.canSend == true {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Write a message…", text: draft, axis: .vertical).lineLimit(1...5).padding(12).background(HOPStyle.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(HOPStyle.border)).disabled(chat.sending).accessibilityLabel("Message")
                    Button { Task { await chat.send(in: conversationID) } } label: { if chat.sending { ProgressView().tint(.white).frame(width: 44, height: 44) } else { Image(systemName: "arrow.up").font(.headline).frame(width: 44, height: 44) } }.foregroundStyle(.white).background(HOPStyle.hero, in: Circle()).disabled(chat.sending || chat.drafts[conversationID]?.isValid != true).accessibilityLabel(chat.sending ? "Sending" : "Send message")
                }
                if let draft = chat.drafts[conversationID], draft.text.utf16.count > 1_800 { Text("\(draft.text.utf16.count) / 2,000").font(.caption).foregroundStyle(draft.isValid ? Color.secondary : Color.red) }
                if let notice = chat.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            } else if let detail = chat.detail { Label(detail.blocked ? "Direct messaging is blocked. Previous messages remain visible." : "Only managers can post announcements.", systemImage: detail.blocked ? "hand.raised" : "megaphone").font(.caption).foregroundStyle(.secondary).padding(.vertical, 4) }
        }.padding(14).background(HOPStyle.paper).overlay(alignment: .top) { Divider() }
    }
}

struct ChatBubble: View {
    let message: HOPChatMessage
    let own: Bool
    let read: Bool
    var body: some View {
        HStack {
            if own { Spacer(minLength: 34) }
            VStack(alignment: own ? .trailing : .leading, spacing: 5) {
                Text(own ? "You" : message.senderName).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text(verbatim: message.body).font(.body).textSelection(.enabled).padding(13).foregroundStyle(own ? Color.white : Color.primary).background(own ? HOPStyle.hero : HOPStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                HStack(spacing: 8) { Text(messageTimestamp(message.createdAt)); if own && read { Text("Read") } }.font(.caption2).foregroundStyle(.secondary)
            }
            if !own { Spacer(minLength: 34) }
        }.frame(maxWidth: .infinity)
    }
}

private func messageTimestamp(_ value: String) -> String {
    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return "" }
    return date.formatted(date: .abbreviated, time: .shortened)
}

struct ReportMessageView: View {
    let message: HOPChatMessage
    @EnvironmentObject private var chat: HOPMessages
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    var body: some View {
        Form {
            Section("Selected message") { Text(message.senderName).font(.headline); Text(verbatim: message.body).font(.subheadline) }
            Section("Why are you reporting this?") { TextField("Reason", text: $reason, axis: .vertical).lineLimit(4...8).accessibilityLabel("Report reason") }
            Section { Text("Only this message, your name and your reason are shared with HOP managers. The rest of your private conversation is not shared.").font(.caption).foregroundStyle(.secondary) }
            if let error = chat.error { Text(error).foregroundStyle(.red).font(.subheadline) }
            Button("Send report", systemImage: "flag") { Task { if await chat.report(message.id, reason: reason) { dismiss() } } }.disabled(!HOPChatPolicy.reportIsValid(reason) || chat.actionBusy)
        }.navigationTitle("Report message").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
    }
}

struct MessageReportsView: View {
    @EnvironmentObject private var chat: HOPMessages
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section { Text("Only messages explicitly reported by a participant appear here. Manager access does not open unrelated private conversations.").font(.subheadline).foregroundStyle(.secondary) }
            if let error = chat.error { MessageErrorView(message: error) { Task { await chat.loadReports() } } }
            if chat.reports.isEmpty { Text("No reported messages.").foregroundStyle(.secondary) }
            ForEach(chat.reports) { report in Section {
                HStack { Text(report["sender_name"].text).font(.headline); Spacer(); HOPStatus(value: report.status) }
                Text(verbatim: report["body"].text)
                Text("Reported by \(report["reporter_name"].text) · \(messageTimestamp(report["created_at"].text))").font(.caption).foregroundStyle(.secondary)
                Text(verbatim: report["reason"].text).font(.subheadline)
                if report.status == "open" { Button("Mark reviewed", systemImage: "checkmark.shield") { Task { await chat.resolve(report.id) } }.disabled(chat.actionBusy) }
            } }
        }.navigationTitle("Reported messages").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }.task { await chat.loadReports() }.refreshable { await chat.loadReports() }
    }
}

struct HomeMessagesCard: View {
    @EnvironmentObject private var store: HOPStore
    @EnvironmentObject private var chat: HOPMessages
    var body: some View {
        Button { store.openMessages() } label: {
            HOPCard { HStack(spacing: 14) { Image(systemName: "bubble.left.and.bubble.right.fill").font(.title2).foregroundStyle(HOPStyle.green).frame(width: 48, height: 48).background(HOPStyle.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 15)); VStack(alignment: .leading, spacing: 5) { Text("Team messages").font(.headline); Text(chat.unread > 0 ? "\(chat.unread) unread · catch up with your team" : "Private chats and your team conversations").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(HOPStyle.green) } }
        }.buttonStyle(.plain).task { await chat.refreshSummary() }
    }
}
