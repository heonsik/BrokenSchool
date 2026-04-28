local GameConfig = {
    WorldFolderName = "BrokenSchoolWorld",
    RemotesFolderName = "BrokenSchoolRemotes",

    Messages = {
        Objective = "퓨즈 3개를 모아 발전기를 켜고 탈출문을 여세요",
        Caught = "괴물에게 잡혔어요!",
        Escaped = "탈출 성공!",
        SlideReady = "슬라이딩 가능",
        SlideCooling = "슬라이딩 대기",
        DoorLocked = "탈출문은 아직 잠겨 있어요. 퓨즈를 모아 발전기를 켜세요!",
        NeedMoreFuses = "퓨즈가 더 필요해요.",
        GeneratorReady = "발전기를 켰어요! 탈출문이 열렸습니다.",
        FinalChase = "비상 사이렌! 괴물이 더 빨라졌어요. 지금 탈출하세요!",
        FuseCollected = "퓨즈를 찾았어요!",
        FlashlightCollected = "손전등 획득! F키로 켜고 끌 수 있어요.",
        BoostCollected = "에너지 음료! 잠깐 빨라집니다.",
        ShieldCollected = "보호 부적 획득! 한 번 잡힘을 막아줘요.",
        ShieldUsed = "보호 부적이 괴물을 밀어냈어요!",
        Hidden = "사물함 안에서는 괴물이 잘 못 찾아요.",
        Guide = "로비: 복도 바닥의 파란 불빛을 따라가. 퓨즈 3개가 먼저야!",
        Noise = "소리가 났어요! 괴물이 더 멀리서도 눈치챕니다!",
        FlashlightBlock = "손전등이 괴물의 눈을 부셨어요! 잠시 느려집니다!",
        GhostNear = "차가운 기운이 스쳐 지나갔어요...",
    },

    Spawn = {
        Position = Vector3.new(-52, 2, 23),
    },

    Victory = {
        Position = Vector3.new(330, 3, 0),
    },

    Exit = {
        Position = Vector3.new(305, 3, 0),
        Size = Vector3.new(10, 8, 18),
    },

    Monster = {
        SpawnPosition = Vector3.new(-6, 4, 0),
        MoveY = 4,
        PatrolSpeed = 8,
        ChaseSpeed = 15,
        DetectionRange = 34,
        LoseRange = 46,
        CatchRange = 4.5,
        CatchCooldown = 1.5,
        FinalChaseBonusChaseSpeed = 5,
        FinalChaseBonusPatrolSpeed = 2,
        FlashlightSlowSpeed = 4,
        PathRecomputeChaseInterval = 1.2,
        PathRecomputePatrolInterval = 5.0,
        Waypoints = {
            Vector3.new(-35, 4, 0),
            Vector3.new(-8, 4, 0),
            Vector3.new(18, 4, 0),
            Vector3.new(42, 4, 0),
            Vector3.new(105, 4, 0),
            Vector3.new(180, 4, -90),
            Vector3.new(260, 4, 0),
            Vector3.new(170, 4, 120),
            Vector3.new(40, 4, 150),
            Vector3.new(-120, 4, 110),
            Vector3.new(-230, 4, 0),
            Vector3.new(-160, 4, -130),
            Vector3.new(18, 4, -24),
            Vector3.new(-12, 4, -24),
            Vector3.new(-30, 4, 22),
        },
    },

    Ghost = {
        SpawnPosition = Vector3.new(6, 6, 28),
        MoveY = 6,
        FloatSpeed = 5,
        ScareRange = 16,
        ScareCooldown = 7,
        Waypoints = {
            Vector3.new(6, 6, 28),
            Vector3.new(-60, 6, 120),
            Vector3.new(-210, 6, 130),
            Vector3.new(-260, 6, -60),
            Vector3.new(-80, 6, -150),
            Vector3.new(80, 6, -150),
            Vector3.new(230, 6, -80),
            Vector3.new(260, 6, 120),
            Vector3.new(28, 6, 26),
        },
    },

    Slide = {
        KeyName = "왼쪽 Ctrl / C",
        Speed = 64,
        Duration = 0.24,
        Cooldown = 2,
    },

    Player = {
        DefaultWalkSpeed = 16,
        BoostWalkSpeed = 24,
        BoostDuration = 8,
    },

    Objective = {
        RequiredFuses = 3,
    },

    Items = {
        Fuses = {
            Vector3.new(-190, 2.4, 135),
            Vector3.new(135, 2.4, -155),
            Vector3.new(255, 2.4, 110),
        },
        Flashlight = Vector3.new(-55, 2.2, 29),
        BoostDrink = Vector3.new(95, 2.2, -122),
        ShieldCharm = Vector3.new(-245, 2.2, 88),
        Generator = Vector3.new(230, 2.2, -145),
    },

    Rain = {
        Duration = 180,
        ClearDuration = 600,
        InitialClearDuration = 45,
        FadeTime = 4,
        ParticleRate = 900,
        SoundVolume = 0.32,
        LightningMinDelay = 18,
        LightningMaxDelay = 45,
        ThunderMinDelay = 0.7,
        ThunderMaxDelay = 2.4,
        ThunderVolume = 0.7,
    },

    -- rbxassetid:// 형식으로 수정 (올바른 Roblox 에셋 ID 형식)
    -- 소리가 어색하면 Roblox 오디오 라이브러리에서 교체하세요
    Sounds = {
        Ambience   = "rbxassetid://9041540221",
        MonsterNear = "rbxassetid://2645676598",
        Caught     = "rbxassetid://4962698843",
        Escaped    = "rbxassetid://4612431428",
        Rain       = "rbxassetid://9112854440",
        Thunder    = "rbxassetid://9120386431",
    },
}

return GameConfig
