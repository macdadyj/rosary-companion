# Recorded prayers

Rosary reads its parts aloud with an on-device voice. Any fixed wording can instead be played
from a recording, part by part, with no code changes: add the audio file and rebuild. Parts
without a recording keep using the voice, so a set can be recorded a few files at a time.

## How to add recordings

1. Record the exact words listed below, one file per slot. A calm, unhurried reading suits the
   app; leave about a quarter of a second of silence at each end (the app adds its own pauses
   between parts).
2. Name each file after its slot plus an extension: `m4a` (AAC, recommended), `caf`, `wav`,
   `aiff` or `mp3`. For example `prayer.hailMary.m4a`.
3. Put the files in `Sources/RosaryCore/Resources/Recordings/` and rebuild with xtool.

Names and other text that changes between sessions ("Mom leads the next decade.") are always
spoken by the voice. If a recording can't be played, the voice reads that part instead.

The `.holyGhost` files are used when Settings > Say "Holy Ghost" is on, and only for the prayers
whose words change. Every other prayer uses the same file either way.

Only the leader's part of each prayer is read aloud; the response is prayed by the people
praying, so it needs no recording. Prayers said by everyone together (the Fatima Prayer) have no
slot. `NarrationClip.all` in `Sources/RosaryCore/Narration/Narration.swift` is the source of
this list, and a test checks that this file matches it.

## Prayers (the part the app leads)

- `prayer.signOfTheCross`: In the name of the Father, and of the Son, and of the Holy Spirit. Amen.
- `prayer.signOfTheCross.holyGhost`: In the name of the Father, and of the Son, and of the Holy Ghost. Amen.
- `prayer.apostlesCreed`: I believe in God, the Father almighty, Creator of heaven and earth; and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died, and was buried. He descended into hell; the third day he rose again from the dead; he ascended into heaven, and sitteth at the right hand of God, the Father almighty; from thence he shall come to judge the living and the dead.
- `prayer.apostlesCreed.holyGhost`: I believe in God, the Father almighty, Creator of heaven and earth; and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Ghost, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died, and was buried. He descended into hell; the third day he rose again from the dead; he ascended into heaven, and sitteth at the right hand of God, the Father almighty; from thence he shall come to judge the living and the dead.
- `prayer.ourFather`: Our Father, who art in heaven, hallowed be thy name; thy kingdom come, thy will be done on earth as it is in heaven.
- `prayer.hailMary`: Hail Mary, full of grace, the Lord is with thee; blessed art thou among women, and blessed is the fruit of thy womb, Jesus.
- `prayer.gloryBe`: Glory be to the Father, and to the Son, and to the Holy Spirit.
- `prayer.gloryBe.holyGhost`: Glory be to the Father, and to the Son, and to the Holy Ghost.
- `prayer.hailHolyQueen`: Hail, holy Queen, Mother of mercy, our life, our sweetness and our hope.
- `prayer.rosaryVersicle`: Pray for us, O holy Mother of God.
- `prayer.closingPrayer`: Let us pray. O God, whose only-begotten Son, by his life, death, and resurrection, has purchased for us the rewards of eternal life; grant, we beseech thee, that, meditating upon these mysteries of the most holy Rosary of the Blessed Virgin Mary, we may imitate what they contain and obtain what they promise, through the same Christ our Lord. Amen.

## Opening intentions

- `intention.faith`: For an increase of faith.
- `intention.hope`: For an increase of hope.
- `intention.charity`: For an increase of charity.

## Mystery announcements

- `mystery.annunciation`: The First Joyful Mystery: The Annunciation.
- `mystery.visitation`: The Second Joyful Mystery: The Visitation.
- `mystery.nativity`: The Third Joyful Mystery: The Nativity.
- `mystery.presentation`: The Fourth Joyful Mystery: The Presentation in the Temple.
- `mystery.findingInTemple`: The Fifth Joyful Mystery: The Finding of Jesus in the Temple.
- `mystery.baptism`: The First Luminous Mystery: The Baptism of the Lord.
- `mystery.weddingAtCana`: The Second Luminous Mystery: The Wedding at Cana.
- `mystery.proclamation`: The Third Luminous Mystery: The Proclamation of the Kingdom.
- `mystery.transfiguration`: The Fourth Luminous Mystery: The Transfiguration.
- `mystery.eucharist`: The Fifth Luminous Mystery: The Institution of the Eucharist.
- `mystery.agonyInGarden`: The First Sorrowful Mystery: The Agony in the Garden.
- `mystery.scourging`: The Second Sorrowful Mystery: The Scourging at the Pillar.
- `mystery.crowningWithThorns`: The Third Sorrowful Mystery: The Crowning with Thorns.
- `mystery.carryingCross`: The Fourth Sorrowful Mystery: The Carrying of the Cross.
- `mystery.crucifixion`: The Fifth Sorrowful Mystery: The Crucifixion and Death of Our Lord.
- `mystery.resurrection`: The First Glorious Mystery: The Resurrection.
- `mystery.ascension`: The Second Glorious Mystery: The Ascension.
- `mystery.descentOfHolySpirit`: The Third Glorious Mystery: The Descent of the Holy Spirit.
- `mystery.assumption`: The Fourth Glorious Mystery: The Assumption of Mary.
- `mystery.coronation`: The Fifth Glorious Mystery: The Coronation of Mary.
