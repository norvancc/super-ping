import Foundation
public struct EmoteDefinition: Identifiable {
    public let id: String
    public let name: String
    public let nameZh: String
    public var title: String { Localized.text(name, nameZh) }
    public static let defaultWheel = ["unworthy_cn", "poro_snax", "sad_kitten", "cheeky_poro", "angry_kitty", "gg_heart", "bee_happy", "bee_mad"]
    public static let catalog: [EmoteDefinition] = [
        .init(id: "facepalm", name: "Facepalm", nameZh: "捂脸"),
        .init(id: "unworthy", name: "Unworthy", nameZh: "弱爆"),
        .init(id: "unworthy_cn", name: "Unworthy (Chinese text)", nameZh: "弱爆（文字版）"),
        .init(id: "poro_snax", name: "Poro Snax", nameZh: "魄罗佳肴"),
        .init(id: "sad_kitten", name: "Sad Kitten", nameZh: "悲伤猫咪"),
        .init(id: "cheeky_poro", name: "Cheeky Poro", nameZh: "调皮魄罗"),
        .init(id: "angry_kitty", name: "Angry Kitty", nameZh: "我生气了！"),
        .init(id: "gg_heart", name: "GG <3", nameZh: "精彩的对局 <3"),
        .init(id: "bee_happy", name: "Bee Happy", nameZh: "小蜜蜂 高兴"),
        .init(id: "bee_mad", name: "Bee Mad", nameZh: "小蜜蜂 疯狂"),
        .init(id: "bee_sad", name: "Bee Sad", nameZh: "小蜜蜂 悲伤"),
        .init(id: "snoozy_poro", name: "Snoozy Poro", nameZh: "打盹魄罗"),
        .init(id: "wahaha", name: "Wahaha", nameZh: "笑哭我了"),
        .init(id: "omg_love_it", name: "OMG I love it", nameZh: "我的天，爱死它了"),
        .init(id: "poro_ride", name: "Poro Ride", nameZh: "溜了溜了"),
        .init(id: "dont_make_me_laugh", name: "Don't Make Me Laugh", nameZh: "xswl"),
        .init(id: "woah_dizzy", name: "Woah…Dizzy", nameZh: "晕晕"),
        .init(id: "haha_hilarious", name: "Haha HILARIOUS", nameZh: "哈哈笑死"),
        .init(id: "gasp", name: "Gasp!", nameZh: "倒吸一口凉气！"),
        .init(id: "super_approved", name: "Super-Approved", nameZh: "超赞的"),
        .init(id: "pain", name: "PaiN…", nameZh: "强颜欢笑"),
        .init(id: "laughing_out_loud", name: "Laughing Out LOUD", nameZh: "哈哈哈"),
        .init(id: "hats_off", name: "Hat's Off", nameZh: "脱帽致意"),
        .init(id: "call_me", name: "Call Me!", nameZh: "双击666！"),
        .init(id: "think_about_it", name: "Think About It", nameZh: "脑子是个好东西"),
        .init(id: "unimpressed", name: "Animated Unimpressed!", nameZh: "凡人！动态表情"),
        .init(id: "did_you_just", name: "Animated Did You Just?", nameZh: "动态 我太难了！"),
        .init(id: "nice_try", name: "Nice Try", nameZh: "棒棒哒"),
        .init(id: "nice", name: "Nice", nameZh: "干得漂亮"),
        .init(id: "despair", name: "Despair", nameZh: "呜呜呜---"),
        .init(id: "does_not_compute", name: "Does Not Compute", nameZh: "无法求解"),
        .init(id: "come_at_me", name: "Come at Me", nameZh: "放马过来"),
        .init(id: "how_could_you", name: "How Could You", nameZh: "你怎能这样"),
        .init(id: "scout_approved", name: "Scout-Approved", nameZh: "提莫说很好"),
        .init(id: "maybe_next_time", name: "Maybe Next Time", nameZh: "也许下次"),
        .init(id: "okay", name: "Okay", nameZh: "OK"),
        .init(id: "good_job_buddy", name: "Good Job, Buddy!", nameZh: "干得好，伙计！"),
        .init(id: "teamwork", name: "Teamwork!", nameZh: "团队协作！"),
        .init(id: "i_will_destroy_you", name: "I will destroy you", nameZh: "你瞅啥？"),
        .init(id: "not_today", name: "Not Today!", nameZh: "没门！"),
        .init(id: "oh", name: "Oh...", nameZh: "大受震撼"),
        .init(id: "come_again", name: "Come again?", nameZh: "一脸问号"),
        .init(id: "magpie_oopsie", name: "Magpie Oopsie", nameZh: "雀实有问题"),
        .init(id: "such_foolishness", name: "Such Foolishness", nameZh: "如此愚蠢"),
    ]
}
