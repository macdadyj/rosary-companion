import Foundation

public enum PrayerCategory: String, CaseIterable, Hashable, Sendable, Identifiable {
    case ourLady
    case protection
    case litanies
    case chaplets
    case daily
    case byzantine

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ourLady: "Our Lady"
        case .protection: "Saint Michael and protection"
        case .litanies: "Litanies"
        case .chaplets: "Chaplets"
        case .daily: "Daily"
        case .byzantine: "Byzantine"
        }
    }

    /// Short name for a chip. The full title stays the accessibility label.
    public var chipTitle: String {
        switch self {
        case .ourLady: "Our Lady"
        case .protection: "Protection"
        case .litanies: "Litanies"
        case .chaplets: "Chaplets"
        case .daily: "Daily"
        case .byzantine: "Byzantine"
        }
    }
}

public struct LibraryPrayer: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let category: PrayerCategory
    public let body: String
    public let source: String
    public let licenseNote: String
    /// Devotion plan to open when the prayer is also prayed bead by bead.
    public let devotionID: String?

    public init(
        id: String,
        title: String,
        category: PrayerCategory,
        body: String,
        source: String,
        licenseNote: String = "Public domain",
        devotionID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.body = body
        self.source = source
        self.licenseNote = licenseNote
        self.devotionID = devotionID
    }
}

/// Public-domain prayers for the laity. Texts are traditional English.
/// Copyrighted invocations and priest-only rites are omitted on purpose.
public enum PrayerLibrary {
    public static func matching(_ query: String, in prayers: [LibraryPrayer]) -> [LibraryPrayer] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return prayers }
        return prayers.filter {
            $0.title.localizedStandardContains(needle) || $0.body.localizedStandardContains(needle)
        }
    }

    public static func catalog(book: PrayerBook = PrayerBook(), content: PrayerContent? = nil) -> [LibraryPrayer] {
        var prayers = ourLady(book: book) + protection + litanies + daily + byzantine
        prayers.append(contentsOf: chaplets(book: book, content: content))
        if let hours = content?.hours {
            prayers.append(LibraryPrayer(
                id: "angelus",
                title: "The Angelus",
                category: .ourLady,
                body: hours.angelus.joined(separator: "\n"),
                source: hours.source
            ))
            prayers.append(LibraryPrayer(
                id: "regina-caeli",
                title: "Regina Caeli",
                category: .ourLady,
                body: hours.reginaCaeli.joined(separator: "\n"),
                source: hours.source
            ))
        }
        if let litany = content?.litany {
            let body = litany.rows.map { row in
                row.latin.isEmpty ? row.english : "\(row.english)\n\(row.latin)"
            }.joined(separator: "\n\n")
            prayers.append(LibraryPrayer(
                id: "litany-loreto",
                title: litany.title,
                category: .litanies,
                body: body,
                source: litany.source
            ))
        }
        return prayers
    }

    private static func ourLady(book: PrayerBook) -> [LibraryPrayer] {
        [
            LibraryPrayer(
                id: "memorare",
                title: "The Memorare",
                category: .ourLady,
                body: LayPrayers.memorare,
                source: "Traditional English of the Memorare, long in use in Catholic prayer books."
            ),
            LibraryPrayer(
                id: "hail-holy-queen",
                title: "Hail, Holy Queen",
                category: .ourLady,
                body: book.text(for: .hailHolyQueen).full,
                source: "Traditional English, the same text as the Rosary's closing prayer."
            ),
            LibraryPrayer(
                id: "sub-tuum",
                title: "Sub Tuum Praesidium",
                category: .ourLady,
                body: LayPrayers.subTuum,
                source: "Traditional English of the oldest known prayer to the Mother of God."
            ),
            LibraryPrayer(
                id: "magnificat",
                title: "The Magnificat",
                category: .ourLady,
                body: LayPrayers.magnificat,
                source: "Douay-Rheims, Challoner revision, Luke 1:46–55."
            ),
            LibraryPrayer(
                id: "montfort-consecration",
                title: "Consecration to Mary",
                category: .ourLady,
                body: LayPrayers.montfortConsecration,
                source: "Short consecration from Saint Louis de Montfort, True Devotion to Mary, translated by Father Frederick William Faber (1863)."
            ),
        ]
    }

    private static let protection: [LibraryPrayer] = [
        LibraryPrayer(
            id: "st-michael-short",
            title: "Prayer to Saint Michael",
            category: .protection,
            body: LayPrayers.saintMichaelShort,
            source: "The short prayer of Pope Leo XIII (1886) for the faithful after Low Mass."
        ),
        LibraryPrayer(
            id: "st-michael-petition",
            title: "Prayer to Saint Michael, longer petition",
            category: .protection,
            body: LayPrayers.saintMichaelPetition,
            source: "The lay petition to Saint Michael from the era of Pope Leo XIII. The imperative formula reserved to priests is not part of this prayer."
        ),
        LibraryPrayer(
            id: "vade-retro",
            title: "Prayer of the Medal of Saint Benedict",
            category: .protection,
            body: LayPrayers.vadeRetro,
            source: "Traditional English of the words on the Medal of Saint Benedict."
        ),
        LibraryPrayer(
            id: "breastplate",
            title: "Breastplate of Saint Patrick",
            category: .protection,
            body: LayPrayers.breastplate,
            source: "Lorica of Saint Patrick, the complete hymn translated by Cecil Frances Alexander (1889)."
        ),
        LibraryPrayer(
            id: "anima-christi",
            title: "Anima Christi",
            category: .protection,
            body: LayPrayers.animaChristi,
            source: "Traditional English of the Anima Christi, a medieval prayer."
        ),
    ]

    private static let litanies: [LibraryPrayer] = [
        LibraryPrayer(
            id: "litany-sacred-heart",
            title: "Litany of the Sacred Heart",
            category: .litanies,
            body: LayPrayers.litanySacredHeart,
            source: "Litany of the Sacred Heart approved by Pope Leo XIII in 1899. Traditional English."
        ),
        LibraryPrayer(
            id: "litany-st-joseph",
            title: "Litany of Saint Joseph",
            category: .litanies,
            body: LayPrayers.litanySaintJoseph,
            source: "Litany of Saint Joseph approved by Pope Saint Pius X in 1909. Traditional English of that edition."
        ),
        LibraryPrayer(
            id: "litany-humility",
            title: "Litany of Humility",
            category: .litanies,
            body: LayPrayers.litanyHumility,
            source: "Cardinal Rafael Merry del Val, died 1930. Traditional English, public domain in the United States."
        ),
    ]

    private static func chaplets(book: PrayerBook, content: PrayerContent?) -> [LibraryPrayer] {
        var prayers = [
            LibraryPrayer(
                id: "st-michael-chaplet",
                title: "Chaplet of Saint Michael",
                category: .chaplets,
                body: DevotionCatalog.stMichaelChaplet(book: book).fullText,
                source: DevotionCatalog.stMichaelChaplet(book: book).source,
                devotionID: "stMichael"
            ),
            LibraryPrayer(
                id: "divine-mercy",
                title: "Chaplet of Divine Mercy",
                category: .chaplets,
                body: LayPrayers.divineMercyNote,
                source: "Bead pattern only. The invocations are copyrighted by the Marians of the Immaculate Conception.",
                licenseNote: "Invocations omitted. Copyright Marians of the Immaculate Conception.",
                devotionID: content == nil ? nil : "divineMercy"
            ),
        ]
        if let content {
            let sorrows = DevotionCatalog.sevenSorrows(book: book, content: content)
            prayers.append(LibraryPrayer(
                id: "seven-sorrows",
                title: sorrows.title,
                category: .chaplets,
                body: sorrows.fullText,
                source: sorrows.source,
                devotionID: "sevenSorrows"
            ))
        }
        return prayers
    }

    private static let daily: [LibraryPrayer] = [
        LibraryPrayer(
            id: "act-of-contrition",
            title: "Act of Contrition",
            category: .daily,
            body: LayPrayers.actOfContrition,
            source: "Traditional English act of contrition."
        ),
        LibraryPrayer(
            id: "morning-offering",
            title: "Morning Offering",
            category: .daily,
            body: LayPrayers.morningOffering,
            source: "A morning offering of the Apostleship of Prayer in the form used in manuals before 1929."
        ),
        LibraryPrayer(
            id: "prayer-st-joseph",
            title: "Prayer to Saint Joseph",
            category: .daily,
            body: LayPrayers.prayerToSaintJoseph,
            source: "Ad te, beate Ioseph, Pope Leo XIII, 1889. Traditional English."
        ),
        LibraryPrayer(
            id: "te-deum",
            title: "Te Deum",
            category: .daily,
            body: LayPrayers.teDeum,
            source: "Traditional English of the Te Deum."
        ),
        LibraryPrayer(
            id: "before-crucifix",
            title: "Prayer before a Crucifix",
            category: .daily,
            body: LayPrayers.beforeCrucifix,
            source: "En ego, the traditional prayer before a crucifix, from the Raccolta in English."
        ),
        LibraryPrayer(
            id: "before-communion",
            title: "Prayer before Communion",
            category: .daily,
            body: LayPrayers.beforeCommunion,
            source: "Traditional English of the prayer before Communion in the Roman Missal."
        ),
        LibraryPrayer(
            id: "after-communion",
            title: "Prayer after Communion",
            category: .daily,
            body: LayPrayers.afterCommunion,
            source: "Traditional English thanksgiving after Communion."
        ),
        LibraryPrayer(
            id: "jesus-prayer",
            title: "The Jesus Prayer",
            category: .daily,
            body: LayPrayers.jesusPrayer,
            source: "The traditional prayer of the Christian East."
        ),
    ]

    private static let byzantine: [LibraryPrayer] = [
        LibraryPrayer(
            id: "axion-estin",
            title: "It Is Truly Proper",
            category: .byzantine,
            body: LayPrayers.axionEstin,
            source: "Traditional English of the hymn Axion Estin, to the Theotokos."
        ),
        LibraryPrayer(
            id: "theotokos-rejoice",
            title: "Rejoice, O Virgin Theotokos",
            category: .byzantine,
            body: LayPrayers.theotokosRejoice,
            source: "Traditional English of the Theotokos troparion."
        ),
        LibraryPrayer(
            id: "theotokos-kontakion",
            title: "Kontakion to the Theotokos",
            category: .byzantine,
            body: LayPrayers.theotokosKontakion,
            source: "Traditional English of the kontakion. The full Akathist, all twenty-four stanzas, is a separate hymn and is not printed here."
        ),
    ]
}

public enum LayPrayers {
    public static let memorare = """
    Remember, O most gracious Virgin Mary, that never was it known that anyone who fled to thy protection, implored thy help, or sought thy intercession, was left unaided. Inspired by this confidence, I fly unto thee, O Virgin of virgins, my Mother. To thee do I come, before thee I stand, sinful and sorrowful. O Mother of the Word Incarnate, despise not my petitions, but in thy mercy hear and answer me. Amen.
    """

    public static let subTuum = """
    We fly to thy patronage, O holy Mother of God. Despise not our petitions in our necessities, but deliver us always from all dangers, O glorious and blessed Virgin. Amen.
    """

    public static let magnificat = """
    46 And Mary said: My soul doth magnify the Lord.
    47 And my spirit hath rejoiced in God my Saviour.
    48 Because he hath regarded the humility of his handmaid: for behold from henceforth all generations shall call me blessed.
    49 Because he that is mighty hath done great things to me: and holy is his name.
    50 And his mercy is from generation unto generations, to them that fear him.
    51 He hath shewed might in his arm: he hath scattered the proud in the conceit of their heart.
    52 He hath put down the mighty from their seat and hath exalted the humble.
    53 He hath filled the hungry with good things: and the rich he hath sent empty away.
    54 He hath received Israel his servant, being mindful of his mercy.
    55 As he spoke to our fathers: to Abraham and to his seed for ever.
    """

    public static let montfortConsecration = """
    I, N., a faithless sinner, renew and ratify today in thy hands the vows of my Baptism. I renounce forever Satan, his pomps and works, and I give myself entirely to Jesus Christ, the Incarnate Wisdom, to carry my cross after him all the days of my life, and to be more faithful to him than I have ever been before.

    In the presence of all the heavenly court I choose thee this day for my Mother and Queen. I deliver and consecrate to thee, as thy slave, my body and soul, my goods, both interior and exterior, and even the value of all my good actions, past, present, and future, leaving to thee the entire and full right of disposing of me, and all that belongs to me, without exception, according to thy good pleasure, for the greater glory of God in time and in eternity. Amen.
    """

    public static let saintMichaelShort = """
    Saint Michael the Archangel, defend us in battle. Be our protection against the wickedness and snares of the devil. May God rebuke him, we humbly pray; and do thou, O Prince of the heavenly host, by the power of God, cast into hell Satan and all the evil spirits who prowl about the world seeking the ruin of souls. Amen.
    """

    public static let saintMichaelPetition = """
    O glorious Prince of the heavenly host, Saint Michael the Archangel, defend us in the battle and in the fearful warfare we are waging against principalities and powers, against the rulers of this world of darkness, against the spirits of wickedness in the high places. Come to the aid of men, whom God created immortal, made in his own image and likeness, and redeemed at a great price from the tyranny of the devil.

    Fight this day the battle of the Lord, together with the holy angels, as already thou hast fought the leader of the proud angels, Lucifer, and his apostate host, who were powerless to resist thee, nor was there place for them any longer in heaven. That cruel, ancient serpent, who is called the devil or Satan, who seduces the whole world, was cast into the abyss with his angels. Behold, this primeval enemy and slayer of men has taken courage. Transformed into an angel of light, he wanders about with all the multitude of wicked spirits, invading the earth in order to blot out the name of God and of his Christ, to seize upon, slay, and cast into eternal perdition souls destined for the crown of eternal glory. This wicked dragon pours out, as a most impure flood, the venom of his malice on men of depraved mind and corrupt heart, the spirit of lying, of impiety, of blasphemy, and the pestilent breath of impurity and of every vice and iniquity.

    These most crafty enemies have filled and inebriated with gall and bitterness the Church, the spouse of the immaculate Lamb, and have laid impious hands on her most sacred possessions. In the holy place itself, where the See of most holy Peter and the Chair of Truth were set up as the light of the world, they have raised the throne of their abominable impiety, with the iniquitous design that when the Pastor has been struck the sheep may be scattered.

    Arise then, O invincible Prince, bring help to the people of God against the attacks of the lost spirits, and give them the victory. They venerate thee as their protector and patron. In thee holy Church glories as her defense against the malicious powers of hell. To thee has God entrusted the souls of men to be established in heavenly beatitude. Pray to the God of peace that he may put Satan under our feet, so far conquered that he may no longer be able to hold men in captivity and harm the Church. Offer our prayers in the sight of the Most High, so that they may quickly conciliate the mercies of the Lord; and beating down the dragon, the ancient serpent, who is the devil and Satan, do thou again make him captive in the abyss, that he may no longer seduce the nations. Amen.
    """

    public static let vadeRetro = """
    The Holy Cross be my light. Let not the dragon be my guide.

    Begone, Satan. Suggest not to me thy vanities. Evil are the things thou offerest. Drink thou thine own poison.

    Vade retro, Satana. Numquam suade mihi vana. Sunt mala quae libas. Ipse venena bibas.
    """

    public static let breastplate = """
    I bind unto myself today
    The strong Name of the Trinity,
    By invocation of the same,
    The Three in One and One in Three.

    I bind this day to me for ever,
    By power of faith, Christ's Incarnation;
    His baptism in the Jordan river;
    His death on cross for my salvation;
    His bursting from the spicèd tomb;
    His riding up the heavenly way;
    His coming at the day of doom:
    I bind unto myself today.

    I bind unto myself the power
    Of the great love of cherubim;
    The sweet "Well done" in judgment hour;
    The service of the seraphim;
    Confessors' faith, apostles' word,
    The patriarchs' prayers, the prophets' scrolls;
    All good deeds done unto the Lord,
    And purity of virgin souls.

    I bind unto myself today
    The virtues of the starlit heaven,
    The glorious sun's life-giving ray,
    The whiteness of the moon at even,
    The flashing of the lightning free,
    The whirling wind's tempestuous shocks,
    The stable earth, the deep salt sea,
    Around the old eternal rocks.

    I bind unto myself today
    The power of God to hold and lead,
    His eye to watch, his might to stay,
    His ear to hearken to my need;
    The wisdom of my God to teach,
    His hand to guide, his shield to ward;
    The word of God to give me speech,
    His heavenly host to be my guard.

    Christ be with me, Christ within me,
    Christ behind me, Christ before me,
    Christ beside me, Christ to win me,
    Christ to comfort and restore me,
    Christ beneath me, Christ above me,
    Christ in quiet, Christ in danger,
    Christ in hearts of all that love me,
    Christ in mouth of friend and stranger.

    I bind unto myself the Name,
    The strong Name of the Trinity,
    By invocation of the same,
    The Three in One and One in Three,
    Of whom all nature hath creation,
    Eternal Father, Spirit, Word.
    Praise to the Lord of my salvation:
    Salvation is of Christ the Lord.
    """

    public static let animaChristi = """
    Soul of Christ, sanctify me.
    Body of Christ, save me.
    Blood of Christ, inebriate me.
    Water from the side of Christ, wash me.
    Passion of Christ, strengthen me.
    O good Jesus, hear me.
    Within thy wounds hide me.
    Suffer me not to be separated from thee.
    From the malignant enemy defend me.
    In the hour of my death call me,
    and bid me come unto thee,
    that with thy saints I may praise thee
    for ever and ever. Amen.
    """

    public static let litanyHumility = """
    O Jesus, meek and humble of heart, hear me.

    From the desire of being esteemed, deliver me, Jesus.
    From the desire of being loved, deliver me, Jesus.
    From the desire of being extolled, deliver me, Jesus.
    From the desire of being honored, deliver me, Jesus.
    From the desire of being praised, deliver me, Jesus.
    From the desire of being preferred to others, deliver me, Jesus.
    From the desire of being consulted, deliver me, Jesus.
    From the desire of being approved, deliver me, Jesus.
    From the fear of being humiliated, deliver me, Jesus.
    From the fear of being despised, deliver me, Jesus.
    From the fear of suffering rebukes, deliver me, Jesus.
    From the fear of being calumniated, deliver me, Jesus.
    From the fear of being forgotten, deliver me, Jesus.
    From the fear of being ridiculed, deliver me, Jesus.
    From the fear of being wronged, deliver me, Jesus.
    From the fear of being suspected, deliver me, Jesus.

    That others may be loved more than I, Jesus, grant me the grace to desire it.
    That others may be esteemed more than I, Jesus, grant me the grace to desire it.
    That, in the opinion of the world, others may increase and I may decrease, Jesus, grant me the grace to desire it.
    That others may be chosen and I set aside, Jesus, grant me the grace to desire it.
    That others may be praised and I go unnoticed, Jesus, grant me the grace to desire it.
    That others may be preferred to me in everything, Jesus, grant me the grace to desire it.
    That others may become holier than I, provided that I may become as holy as I should, Jesus, grant me the grace to desire it.
    """

    public static let litanySacredHeart = """
    Lord, have mercy on us. Christ, have mercy on us. Lord, have mercy on us.
    Christ, hear us. Christ, graciously hear us.
    God the Father of Heaven, have mercy on us.
    God the Son, Redeemer of the world, have mercy on us.
    God the Holy Spirit, have mercy on us.
    Holy Trinity, one God, have mercy on us.
    Heart of Jesus, Son of the Eternal Father, have mercy on us.
    Heart of Jesus, formed by the Holy Spirit in the womb of the Virgin Mother, have mercy on us.
    Heart of Jesus, substantially united to the Word of God, have mercy on us.
    Heart of Jesus, of infinite majesty, have mercy on us.
    Heart of Jesus, holy temple of God, have mercy on us.
    Heart of Jesus, tabernacle of the Most High, have mercy on us.
    Heart of Jesus, house of God and gate of heaven, have mercy on us.
    Heart of Jesus, burning furnace of charity, have mercy on us.
    Heart of Jesus, vessel of justice and love, have mercy on us.
    Heart of Jesus, full of goodness and love, have mercy on us.
    Heart of Jesus, abyss of all virtues, have mercy on us.
    Heart of Jesus, most worthy of all praise, have mercy on us.
    Heart of Jesus, king and center of all hearts, have mercy on us.
    Heart of Jesus, in whom are all the treasures of wisdom and knowledge, have mercy on us.
    Heart of Jesus, in whom dwelleth all the fullness of the divinity, have mercy on us.
    Heart of Jesus, in whom the Father is well pleased, have mercy on us.
    Heart of Jesus, of whose fullness we have all received, have mercy on us.
    Heart of Jesus, desire of the everlasting hills, have mercy on us.
    Heart of Jesus, patient and rich in mercy, have mercy on us.
    Heart of Jesus, rich unto all who call upon thee, have mercy on us.
    Heart of Jesus, fount of life and holiness, have mercy on us.
    Heart of Jesus, propitiation for our sins, have mercy on us.
    Heart of Jesus, saturated with revilings, have mercy on us.
    Heart of Jesus, crushed for our iniquities, have mercy on us.
    Heart of Jesus, made obedient unto death, have mercy on us.
    Heart of Jesus, pierced with a lance, have mercy on us.
    Heart of Jesus, source of all consolation, have mercy on us.
    Heart of Jesus, our life and resurrection, have mercy on us.
    Heart of Jesus, our peace and reconciliation, have mercy on us.
    Heart of Jesus, victim for our sins, have mercy on us.
    Heart of Jesus, salvation of those who hope in thee, have mercy on us.
    Heart of Jesus, hope of those who die in thee, have mercy on us.
    Heart of Jesus, delight of all the saints, have mercy on us.
    Lamb of God, who takest away the sins of the world, spare us, O Lord.
    Lamb of God, who takest away the sins of the world, graciously hear us, O Lord.
    Lamb of God, who takest away the sins of the world, have mercy on us.
    V. Jesus, meek and humble of Heart.
    R. Make our hearts like unto thine.
    Let us pray.
    Almighty and eternal God, look upon the Heart of thy well-beloved Son, and upon the praises and satisfaction which he renders thee in the name of sinners; and of thy great goodness grant them pardon when they seek thy mercy, in the name of the same thy Son, Jesus Christ, who liveth and reigneth with thee, world without end. Amen.
    """

    public static let litanySaintJoseph = """
    Lord, have mercy on us. Christ, have mercy on us. Lord, have mercy on us.
    Christ, hear us. Christ, graciously hear us.
    God the Father of Heaven, have mercy on us.
    God the Son, Redeemer of the world, have mercy on us.
    God the Holy Spirit, have mercy on us.
    Holy Trinity, one God, have mercy on us.
    Holy Mary, pray for us.
    Saint Joseph, pray for us.
    Renowned offspring of David, pray for us.
    Light of Patriarchs, pray for us.
    Spouse of the Mother of God, pray for us.
    Chaste guardian of the Virgin, pray for us.
    Foster-father of the Son of God, pray for us.
    Diligent protector of Christ, pray for us.
    Head of the Holy Family, pray for us.
    Joseph most just, pray for us.
    Joseph most chaste, pray for us.
    Joseph most prudent, pray for us.
    Joseph most strong, pray for us.
    Joseph most obedient, pray for us.
    Joseph most faithful, pray for us.
    Mirror of patience, pray for us.
    Lover of poverty, pray for us.
    Model of artisans, pray for us.
    Glory of home life, pray for us.
    Guardian of virgins, pray for us.
    Pillar of families, pray for us.
    Solace of the wretched, pray for us.
    Hope of the sick, pray for us.
    Patron of the dying, pray for us.
    Terror of demons, pray for us.
    Protector of Holy Church, pray for us.
    Lamb of God, who takest away the sins of the world, spare us, O Lord.
    Lamb of God, who takest away the sins of the world, graciously hear us, O Lord.
    Lamb of God, who takest away the sins of the world, have mercy on us.
    V. He made him the lord of his household.
    R. And prince over all his possessions.
    Let us pray.
    O God, who in thine ineffable providence didst choose blessed Joseph to be the spouse of thy most holy Mother: grant, we beseech thee, that we may have for our advocate in heaven him whom we venerate as our protector on earth. Who livest and reignest world without end. Amen.
    """

    public static let divineMercyNote = """
    The pattern of this chaplet is an opening, then five decades, then a closing. This app counts those beads and prints the Our Father, the Hail Mary, and the Apostles' Creed.

    The invocations proper to the chaplet are the copyright of the Marians of the Immaculate Conception. They are prayed from an approved edition, or from the official Divine Mercy page:

    https://www.thedivinemercy.org/message/devotions/chaplet
    """

    public static let actOfContrition = """
    O my God, I am heartily sorry for having offended thee, and I detest all my sins because of thy just punishments, but most of all because they offend thee, my God, who art all good and deserving of all my love. I firmly resolve, with the help of thy grace, to sin no more and to avoid the near occasion of sin. Amen.
    """

    public static let morningOffering = """
    O Jesus, through the Immaculate Heart of Mary, I offer thee my prayers, works, joys, and sufferings of this day for all the intentions of thy Sacred Heart, in union with the Holy Sacrifice of the Mass throughout the world, in reparation for my sins, for the intentions of all our associates, and in particular for the intentions of our Holy Father the Pope. Amen.
    """

    public static let prayerToSaintJoseph = """
    To thee, O blessed Joseph, do we come in our tribulation, and having implored the help of thy most holy spouse, we confidently invoke thy patronage also. Through that charity which bound thee to the Immaculate Virgin Mother of God, and through the paternal love with which thou didst embrace the Child Jesus, we humbly beg thee to look graciously upon the inheritance which Jesus Christ hath purchased by his blood, and with thy power and strength to aid us in our necessities.

    O most watchful Guardian of the Holy Family, defend the chosen children of Jesus Christ. O most loving father, ward off from us every contagion of error and corrupting influence. O our most mighty protector, be propitious to us and from heaven assist us in our struggle with the power of darkness; and, as once thou didst rescue the Child Jesus from deadly peril, so now protect God's holy Church from the snares of the enemy and from all adversity. Shield, too, each one of us by thy constant protection, so that, supported by thy example and thy aid, we may be able to live piously, to die holily, and to obtain eternal happiness in heaven. Amen.
    """

    public static let teDeum = """
    We praise thee, O God; we acknowledge thee to be the Lord.
    All the earth doth worship thee, the Father everlasting.
    To thee all angels cry aloud, the heavens and all the powers therein.
    To thee cherubim and seraphim continually do cry:
    Holy, holy, holy, Lord God of hosts;
    heaven and earth are full of the majesty of thy glory.
    The glorious company of the apostles praise thee.
    The goodly fellowship of the prophets praise thee.
    The noble army of martyrs praise thee.
    The holy Church throughout all the world doth acknowledge thee:
    the Father of an infinite majesty;
    thine honorable, true, and only Son;
    also the Holy Ghost, the Comforter.
    Thou art the King of glory, O Christ.
    Thou art the everlasting Son of the Father.
    When thou tookest upon thee to deliver man, thou didst not abhor the Virgin's womb.
    When thou hadst overcome the sharpness of death, thou didst open the kingdom of heaven to all believers.
    Thou sittest at the right hand of God, in the glory of the Father.
    We believe that thou shalt come to be our judge.
    We therefore pray thee, help thy servants, whom thou hast redeemed with thy precious blood.
    Make them to be numbered with thy saints, in glory everlasting.
    O Lord, save thy people, and bless thine heritage.
    Govern them, and lift them up for ever.
    Day by day we magnify thee,
    and we worship thy name ever, world without end.
    Vouchsafe, O Lord, to keep us this day without sin.
    O Lord, have mercy upon us, have mercy upon us.
    O Lord, let thy mercy lighten upon us, as our trust is in thee.
    O Lord, in thee have I trusted; let me never be confounded.
    """

    public static let beforeCrucifix = """
    Behold, O kind and most sweet Jesus, I cast myself upon my knees in thy sight, and with the most fervent desire of my soul I pray and beseech thee that thou wouldst impress upon my heart lively sentiments of faith, hope, and charity, with true repentance for my sins and a firm purpose of amendment, while with deep affection and grief of soul I ponder within myself and mentally contemplate thy five most precious wounds, having before my eyes that which David the prophet spoke of thee, O good Jesus: They have pierced my hands and my feet; they have numbered all my bones. Amen.
    """

    public static let beforeCommunion = """
    O Lord Jesus Christ, Son of the living God, who by the will of the Father and the cooperation of the Holy Ghost hast by thy death given life to the world: deliver me by this thy most sacred Body and Blood from all my iniquities and from every evil. Make me cling always to thy commandments, and never suffer me to be separated from thee, who livest and reignest with God the Father, in the unity of the Holy Ghost, world without end. Amen.
    """

    public static let afterCommunion = """
    I give thee thanks, O holy Lord, Father almighty, everlasting God, who hast vouchsafed, not for any merits of mine, but of thy great mercy only, to feed me, a sinner, thy unworthy servant, with the precious Body and Blood of thy Son our Lord Jesus Christ. I pray that this holy Communion may not be to me an occasion of guilt unto punishment, but a saving plea for my pardon. May it be to me an armor of faith and a shield of good will. May it root out of me all vice, subdue my passions, and make me perfect in charity, patience, humility, obedience, and every other virtue. May it be a firm defense against the wiles of my enemies, visible and invisible, a perfect quieting of all my impulses, and a firm cleaving to thee, the one true God, and a blessed consummation of my end. And I pray thee that thou wouldst bring me, a sinner, to that unspeakable banquet where thou, with thy Son and the Holy Ghost, art to thy saints true light, full satisfaction, everlasting joy, gladness without end, and perfect happiness. Through the same Christ our Lord. Amen.
    """

    public static let jesusPrayer = """
    Lord Jesus Christ, Son of God, have mercy on me, a sinner.
    """

    public static let axionEstin = """
    It is truly proper to glorify you, O Theotokos, ever blessed, immaculate, and the Mother of our God. More honorable than the cherubim, and beyond compare more glorious than the seraphim, who, a virgin, gave birth to God the Word, you, truly the Theotokos, we magnify.
    """

    public static let theotokosRejoice = """
    O Theotokos, Virgin, rejoice. Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed is the fruit of thy womb, for thou hast borne the Savior of our souls.
    """

    public static let theotokosKontakion = """
    To thee, the champion leader, we thy servants dedicate a feast of victory and of thanksgiving, as ones rescued from sufferings, O Theotokos. But as thou art one with might which is invincible, from all dangers that can be do thou deliver us, that we may cry to thee: Rejoice, O Bride unwedded.
    """
}
