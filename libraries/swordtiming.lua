local SwordTiming = {
    SafeSpacing = 0.296,
    HighSpacing = 0.2925,
    HitFloor = 0.285,
    GapFloor = 0.2915,
    ArrivalFloor = 0.2747,
    CooldownCorrection = (0.017999999225139618 / 10) + 0.013412
}
local WeaponSpacing: {[number]: number} = {
    [0.21] = 0.229,
    [0.25] = 0.249,
    [0.35] = 0.345,
    [0.4] = 0.341,
    [0.6] = 0.63
}

function SwordTiming.Calculate(Speed: number, Fury: number, High: boolean, Budget: number, Hits: number?)
    local Stock: boolean = Speed == 0.3
    local Normal: number = High and SwordTiming.HighSpacing or SwordTiming.SafeSpacing
    local Spacing: number = Stock and Normal or WeaponSpacing[Speed] or Speed + 0.03
    if Hits and Hits ~= 35 then Spacing = math.max(Spacing, 10 / math.max(Hits - 1, 1)) end
    Spacing = math.max(Spacing * Fury, Budget)
    local Scale: number = Spacing / (Stock and Normal or SwordTiming.SafeSpacing)
    local Gap: number = (Scale < 1 and SwordTiming.GapFloor or SwordTiming.HitFloor) * Scale
    if Stock and High then Gap = math.max(Gap, SwordTiming.GapFloor * Fury, Budget) end
    return Spacing, Scale, Gap, math.max(Speed * Fury - SwordTiming.CooldownCorrection, 0), Stock
end

return SwordTiming