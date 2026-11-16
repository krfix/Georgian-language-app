import Foundation

/// One letter of Mkhedruli, the Georgian alphabet: 33 letters, no capitals.
/// Latin spelling follows Georgia's national system (2002): an apostrophe marks the "tight"
/// (ejective) sounds: k', p', t', q', ts', ch'.
struct Letter: Identifiable, Hashable {
    let char: String
    /// The letter's own name, in Latin letters ("an", "ban").
    let name: String
    /// How it is written in Latin letters.
    let latin: String
    /// How it sounds, in plain English.
    let sound: String
    /// A word that starts with the letter: Georgian, Latin spelling, meaning.
    let word: String
    let wordLatin: String
    let meaning: String

    var id: String { char }
}

enum Alphabet {
    /// In alphabetical order.
    static let letters: [Letter] = [
        Letter(char: "ა", name: "an", latin: "a", sound: "a as in father", word: "ანბანი", wordLatin: "anbani", meaning: "alphabet"),
        Letter(char: "ბ", name: "ban", latin: "b", sound: "b as in bed", word: "ბავშვი", wordLatin: "bavshvi", meaning: "child"),
        Letter(char: "გ", name: "gan", latin: "g", sound: "g as in go", word: "გული", wordLatin: "guli", meaning: "heart"),
        Letter(char: "დ", name: "don", latin: "d", sound: "d as in dog", word: "დედა", wordLatin: "deda", meaning: "mother"),
        Letter(char: "ე", name: "en", latin: "e", sound: "e as in bed", word: "ეზო", wordLatin: "ezo", meaning: "yard"),
        Letter(char: "ვ", name: "vin", latin: "v", sound: "v as in van", word: "ვაშლი", wordLatin: "vashli", meaning: "apple"),
        Letter(char: "ზ", name: "zen", latin: "z", sound: "z as in zoo", word: "ზღვა", wordLatin: "zghva", meaning: "sea"),
        Letter(char: "თ", name: "tan", latin: "t", sound: "t with a puff of air, as in top", word: "თბილისი", wordLatin: "tbilisi", meaning: "Tbilisi"),
        Letter(char: "ი", name: "in", latin: "i", sound: "ee as in see, but short", word: "ია", wordLatin: "ia", meaning: "violet (flower)"),
        Letter(char: "კ", name: "k'an", latin: "k'", sound: "tight k, no puff of air", word: "კატა", wordLatin: "k'at'a", meaning: "cat"),
        Letter(char: "ლ", name: "las", latin: "l", sound: "l as in look", word: "ლომი", wordLatin: "lomi", meaning: "lion"),
        Letter(char: "მ", name: "man", latin: "m", sound: "m as in man", word: "მამა", wordLatin: "mama", meaning: "father"),
        Letter(char: "ნ", name: "nar", latin: "n", sound: "n as in no", word: "ნავი", wordLatin: "navi", meaning: "boat"),
        Letter(char: "ო", name: "on", latin: "o", sound: "o as in more, but short", word: "ოთახი", wordLatin: "otakhi", meaning: "room"),
        Letter(char: "პ", name: "p'ar", latin: "p'", sound: "tight p, no puff of air", word: "პური", wordLatin: "p'uri", meaning: "bread"),
        Letter(char: "ჟ", name: "zhan", latin: "zh", sound: "s as in measure", word: "ჟურნალი", wordLatin: "zhurnali", meaning: "magazine"),
        Letter(char: "რ", name: "rae", latin: "r", sound: "rolled r", word: "რძე", wordLatin: "rdze", meaning: "milk"),
        Letter(char: "ს", name: "san", latin: "s", sound: "s as in sun", word: "სახლი", wordLatin: "sakhli", meaning: "house"),
        Letter(char: "ტ", name: "t'ar", latin: "t'", sound: "tight t, no puff of air", word: "ტყე", wordLatin: "t'q'e", meaning: "forest"),
        Letter(char: "უ", name: "un", latin: "u", sound: "oo as in moon, but short", word: "უბანი", wordLatin: "ubani", meaning: "neighbourhood"),
        Letter(char: "ფ", name: "par", latin: "p", sound: "p with a puff of air, as in pen", word: "ფული", wordLatin: "puli", meaning: "money"),
        Letter(char: "ქ", name: "kan", latin: "k", sound: "k with a puff of air, as in kite", word: "ქალაქი", wordLatin: "kalaki", meaning: "city"),
        Letter(char: "ღ", name: "ghan", latin: "gh", sound: "a soft gargle, like the French r", word: "ღვინო", wordLatin: "ghvino", meaning: "wine"),
        Letter(char: "ყ", name: "q'ar", latin: "q'", sound: "tight k from deep in the throat", word: "ყველი", wordLatin: "q'veli", meaning: "cheese"),
        Letter(char: "შ", name: "shin", latin: "sh", sound: "sh as in ship", word: "შაქარი", wordLatin: "shakari", meaning: "sugar"),
        Letter(char: "ჩ", name: "chin", latin: "ch", sound: "ch with a puff of air, as in chin", word: "ჩაი", wordLatin: "chai", meaning: "tea"),
        Letter(char: "ც", name: "tsan", latin: "ts", sound: "ts with a puff of air, as in cats", word: "ცა", wordLatin: "tsa", meaning: "sky"),
        Letter(char: "ძ", name: "dzil", latin: "dz", sound: "dz as in adze", word: "ძაღლი", wordLatin: "dzaghli", meaning: "dog"),
        Letter(char: "წ", name: "ts'il", latin: "ts'", sound: "tight ts, no puff of air", word: "წყალი", wordLatin: "ts'q'ali", meaning: "water"),
        Letter(char: "ჭ", name: "ch'ar", latin: "ch'", sound: "tight ch, no puff of air", word: "ჭიქა", wordLatin: "ch'ika", meaning: "glass (to drink from)"),
        Letter(char: "ხ", name: "khan", latin: "kh", sound: "ch as in Scottish loch", word: "ხე", wordLatin: "khe", meaning: "tree"),
        Letter(char: "ჯ", name: "jan", latin: "j", sound: "j as in jam", word: "ჯიბე", wordLatin: "jibe", meaning: "pocket"),
        Letter(char: "ჰ", name: "hae", latin: "h", sound: "h as in hat", word: "ჰაერი", wordLatin: "haeri", meaning: "air"),
    ]

    /// Letters learners mix up: the puff / tight pairs, and ones that look alike.
    /// The quiz offers these as wrong answers first.
    static let lookalikes: [[String]] = [
        ["კ", "ქ", "ყ"], ["პ", "ფ"], ["ტ", "თ"], ["ც", "წ", "ძ"], ["ჩ", "ჭ", "ჯ"],
        ["ღ", "ხ"], ["ზ", "ჟ"], ["შ", "ჩ"],
        ["ა", "ჰ"], ["ბ", "ზ"], ["დ", "ღ"], ["მ", "შ"], ["ი", "ო"], ["ს", "ხ"],
    ]

    static func letter(_ char: String) -> Letter? { letters.first { $0.char == char } }
}
