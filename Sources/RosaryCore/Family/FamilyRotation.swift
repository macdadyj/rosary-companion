import Foundation

public struct FamilyMember: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

public enum RotationPolicy: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// Each session starts with the person after last session's starter.
    case newStarterEachSession
    /// Each session starts with the person after whoever led the last decade.
    case continueWhereLeftOff

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newStarterEachSession: "A new person starts each time"
        case .continueWhereLeftOff: "Continue where we left off"
        }
    }
}

public struct FamilySettings: Codable, Hashable, Sendable {
    public var isEnabled = false
    public var members: [FamilyMember] = [FamilyMember(name: "Dad"), FamilyMember(name: "Mom")]
    public var policy: RotationPolicy = .newStarterEachSession
    public var announceNextLeader = true
    public var lastStarterID: UUID?
    public var lastLeaderID: UUID?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case isEnabled, members, policy, announceNextLeader, lastStarterID, lastLeaderID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FamilySettings()
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        members = try c.decodeIfPresent([FamilyMember].self, forKey: .members) ?? defaults.members
        policy = try c.decodeIfPresent(RotationPolicy.self, forKey: .policy) ?? defaults.policy
        announceNextLeader = try c.decodeIfPresent(Bool.self, forKey: .announceNextLeader)
            ?? defaults.announceNextLeader
        lastStarterID = try c.decodeIfPresent(UUID.self, forKey: .lastStarterID)
        lastLeaderID = try c.decodeIfPresent(UUID.self, forKey: .lastLeaderID)
    }
}

public enum FamilyRotation {
    public static func member(after id: UUID?, in members: [FamilyMember]) -> FamilyMember? {
        guard !members.isEmpty else { return nil }
        guard let id, let index = members.firstIndex(where: { $0.id == id }) else { return members.first }
        return members[(index + 1) % members.count]
    }

    /// Who begins the next session.
    public static func nextStarter(_ family: FamilySettings) -> FamilyMember? {
        let members = family.members
        guard !members.isEmpty else { return nil }
        switch family.policy {
        case .newStarterEachSession:
            return member(after: family.lastStarterID, in: members)
        case .continueWhereLeftOff:
            if let last = family.lastLeaderID, members.contains(where: { $0.id == last }) {
                return member(after: last, in: members)
            }
            return member(after: family.lastStarterID, in: members)
        }
    }

    /// Leaders for each decade, taking turns from `starter`.
    public static func lineup(starter: FamilyMember, decades: [Int], members: [FamilyMember]) -> [Int: FamilyMember] {
        guard let start = members.firstIndex(where: { $0.id == starter.id }) else { return [:] }
        var result: [Int: FamilyMember] = [:]
        for (offset, decade) in decades.enumerated() {
            result[decade] = members[(start + offset) % members.count]
        }
        return result
    }

    /// Who would begin next time if this session's lineup is prayed in full.
    public static func starterAfter(
        starter: FamilyMember,
        lastLeader: FamilyMember?,
        family: FamilySettings
    ) -> FamilyMember? {
        var next = family
        next.lastStarterID = starter.id
        next.lastLeaderID = lastLeader?.id ?? starter.id
        return nextStarter(next)
    }

    /// Remembers who started and who led last, if at least one decade was prayed.
    public static func recording(
        starter: FamilyMember,
        lastCompletedLeader: FamilyMember?,
        in family: FamilySettings
    ) -> FamilySettings {
        guard let lastCompletedLeader else { return family }
        var updated = family
        updated.lastStarterID = starter.id
        updated.lastLeaderID = lastCompletedLeader.id
        return updated
    }
}
