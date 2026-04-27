const fs = require("fs");
const path = require("path");

const children = [];

const rgb = (r, g, b) => [r / 255, g / 255, b / 255];

function part(name, size, position, color, options = {}) {
  const properties = {
    Anchored: true,
    Size: size,
    Position: position,
    Color: color,
  };

  if (options.material) properties.Material = options.material;
  if (options.transparency !== undefined) properties.Transparency = options.transparency;
  if (options.canCollide !== undefined) properties.CanCollide = options.canCollide;
  if (options.shape) properties.Shape = options.shape;

  children.push({
    name,
    className: "Part",
    properties,
  });
}

function wall(name, position, size, color = rgb(132, 137, 143)) {
  part(name, size, position, color, { material: "Concrete" });
  part(`${name}_Trim`, [size[0], 0.45, size[2]], [position[0], position[1] - 5.6, position[2]], rgb(62, 70, 82));
}

function zone(name, position, size, color) {
  part(name, size, position, color, {
    material: "Neon",
    transparency: 0.35,
    canCollide: false,
  });
}

function marker(name, position, color, size = [7, 45, 7]) {
  part(name, size, position, color, {
    material: "Neon",
    transparency: 0.2,
    canCollide: false,
  });
}

function guide(name, position, size, color = rgb(55, 210, 255)) {
  part(name, size, position, color, {
    material: "Neon",
    transparency: 0.25,
    canCollide: false,
  });
}

function ceiling(name, position, size) {
  part(name, size, position, rgb(195, 198, 205));
}

function column(name, x, z) {
  part(`${name}_Column`, [1.4, 12, 1.4], [x, 6, z], rgb(185, 190, 198));
  part(`${name}_Cap`, [2.2, 0.5, 2.2], [x, 12.25, z], rgb(170, 175, 185));
}

function windowPart(name, position, size = [7, 4.5, 0.2]) {
  part(name, size, position, rgb(175, 220, 255), {
    material: "Glass",
    transparency: 0.5,
    canCollide: false,
  });
}

function room(name, center, color) {
  const [x, , z] = center;
  part(`${name}_Floor`, [56, 0.16, 38], [x, 0.82, z], color, { material: "CeramicTiles" });
  wall(`${name}_NorthWall`, [x, 6, z + 18], [56, 12, 2], color);
  wall(`${name}_EastWall`, [x + 27, 6, z], [2, 12, 36], color);
  wall(`${name}_WestWall`, [x - 27, 6, z], [2, 12, 36], color);
  ceiling(`${name}_Ceiling`, [x, 12.2, z], [56, 0.4, 38]);
  part(`${name}_CeilingLight`, [28, 0.25, 10], [x, 11.2, z + 4], rgb(255, 244, 196), {
    material: "Neon",
    canCollide: false,
  });
  for (let i = -1; i <= 1; i += 1) {
    windowPart(`${name}_Window_E_${i}`, [x + 27.1, 7, z + i * 9], [0.2, 4.5, 7]);
    windowPart(`${name}_Window_W_${i}`, [x - 27.1, 7, z + i * 9], [0.2, 4.5, 7]);
  }
}

function desk(name, x, z) {
  part(`${name}_Top`, [5, 0.5, 3], [x, 1.5, z], rgb(150, 92, 48), { material: "Wood" });
  part(`${name}_LegA`, [0.35, 2, 0.35], [x - 2, 0.25, z - 1], rgb(150, 92, 48), { material: "Wood" });
  part(`${name}_LegB`, [0.35, 1.3, 0.35], [x + 2, -0.05, z + 1], rgb(150, 92, 48), { material: "Wood" });
}

function chair(name, x, z) {
  part(`${name}_Seat`, [2.4, 0.35, 2.2], [x, 1.2, z], rgb(64, 98, 145), { material: "Wood" });
  part(`${name}_Back`, [2.4, 2.2, 0.35], [x, 2.3, z + 1], rgb(64, 98, 145), { material: "Wood" });
}

function locker(name, x, z) {
  part(`${name}_Body`, [3, 7, 2.2], [x, 4, z], rgb(35, 70, 95), { material: "Metal" });
  part(`${name}_Door`, [2.6, 5.8, 0.16], [x, 4, z - 1.15], rgb(45, 105, 135), { material: "Metal" });
}

function shelf(name, x, z) {
  part(`${name}_Case`, [2.2, 7, 10], [x, 4, z], rgb(76, 48, 32), { material: "Wood" });
  part(`${name}_BooksA`, [2.35, 1.1, 8.8], [x, 5.8, z], rgb(95, 120, 170));
  part(`${name}_BooksB`, [2.35, 1.1, 8.8], [x, 3.4, z], rgb(150, 75, 80));
}

function tree(name, x, z, scale = 1) {
  part(`${name}_Trunk`, [2 * scale, 8 * scale, 2 * scale], [x, 4 * scale + 1, z], rgb(95, 55, 28), { material: "Wood" });
  part(`${name}_Leaves`, [8 * scale, 8 * scale, 8 * scale], [x, 10 * scale + 1, z], rgb(45, 130, 72), {
    material: "Grass",
    shape: "Ball",
  });
}

part("Preview_BaseFloor", [700, 1, 460], [0, 0, 0], rgb(92, 98, 105), { material: "Concrete" });
part("MainCorridor_Floor", [640, 0.08, 16], [0, 0.55, 0], rgb(76, 92, 112), { material: "Slate" });
part("NorthCorridor_Floor", [520, 0.08, 14], [20, 0.55, 120], rgb(66, 86, 112), { material: "Slate" });
part("SouthCorridor_Floor", [520, 0.08, 14], [20, 0.55, -145], rgb(66, 86, 112), { material: "Slate" });
part("WestConnector_Floor", [14, 0.08, 260], [-230, 0.56, 0], rgb(66, 86, 112), { material: "Slate" });
part("EastConnector_Floor", [14, 0.08, 260], [250, 0.56, 0], rgb(66, 86, 112), { material: "Slate" });
part("Preview_OpenCeiling", [700, 0.2, 460], [0, 15.5, 0], rgb(130, 138, 150), {
  transparency: 0.8,
  canCollide: false,
});

for (let i = 1; i <= 11; i += 1) guide(`MainGuide_${i}`, [-270 + i * 50, 0.72, 0], [28, 0.08, 1.1]);
for (let i = 1; i <= 8; i += 1) {
  guide(`NorthGuide_${i}`, [-210 + i * 55, 0.72, 120], [30, 0.08, 1.1], rgb(140, 210, 255));
  guide(`SouthGuide_${i}`, [-210 + i * 55, 0.72, -145], [30, 0.08, 1.1], rgb(255, 190, 105));
}
guide("ExitGuide", [285, 0.72, 0], [44, 0.08, 1.3], rgb(95, 230, 145));

wall("NorthOuterWall", [0, 6, 230], [700, 12, 2]);
wall("SouthOuterWall", [0, 6, -230], [700, 12, 2]);
wall("WestOuterWall", [-350, 6, 0], [2, 12, 460]);
wall("EastOuterWallTop", [350, 6, 125], [2, 12, 210]);
wall("EastOuterWallBottom", [350, 6, -125], [2, 12, 210]);

ceiling("MainCorridor_Ceiling", [0, 12.2, 0], [640, 0.4, 16]);
ceiling("NorthCorridor_Ceiling", [20, 12.2, 120], [520, 0.4, 14]);
ceiling("SouthCorridor_Ceiling", [20, 12.2, -145], [520, 0.4, 14]);
ceiling("WestConnector_Ceiling", [-230, 12.2, 0], [14, 0.4, 248]);
ceiling("EastConnector_Ceiling", [250, 12.2, 0], [14, 0.4, 248]);
ceiling("Gym_Ceiling", [-260, 12.2, -145], [86, 0.4, 58]);

for (let i = 0; i <= 5; i += 1) {
  const x = -250 + i * 100;
  column(`MainNorth_${i}`, x, 7);
  column(`MainSouth_${i}`, x, -7);
}
for (let i = 0; i <= 4; i += 1) {
  const x = -200 + i * 100;
  column(`NorthWingWest_${i}`, x, 127);
  column(`NorthWingEast_${i}`, x, 113);
  column(`SouthWingWest_${i}`, x, -138);
  column(`SouthWingEast_${i}`, x, -152);
}

for (let i = 0; i <= 10; i += 1) {
  windowPart(`NorthOuterWindow_${i}`, [-275 + i * 55, 6.5, 229.3]);
  windowPart(`SouthOuterWindow_${i}`, [-275 + i * 55, 6.5, -229.3]);
}
part("NorthOuter_Wainscot", [700, 2.8, 0.22], [0, 1.4, 229.1], rgb(148, 136, 122), { canCollide: false });
part("SouthOuter_Wainscot", [700, 2.8, 0.22], [0, 1.4, -229.1], rgb(148, 136, 122), { canCollide: false });

wall("StartRoom_NorthLeft", [-57, 6, 12], [12, 12, 2]);
wall("StartRoom_NorthRight", [-35, 6, 12], [12, 12, 2]);
wall("StartRoom_West", [-63, 6, 25], [2, 12, 28]);
wall("StartRoom_East", [-29, 6, 25], [2, 12, 28]);
wall("Library_North", [-8, 6, 25], [24, 12, 2]);
wall("Library_West", [-20, 6, 32], [2, 12, 16]);
wall("Library_East", [4, 6, 32], [2, 12, 16]);
wall("ClassroomB_North", [28, 6, 25], [24, 12, 2]);
wall("ClassroomB_West", [16, 6, 32], [2, 12, 16]);
wall("ClassroomB_East", [40, 6, 32], [2, 12, 16]);
wall("Cafeteria_South", [16, 6, -25], [36, 12, 2]);
wall("Cafeteria_West", [-2, 6, -32], [2, 12, 16]);
wall("Cafeteria_East", [34, 6, -32], [2, 12, 16]);

room("ScienceRoom", [-185, 0, 135], rgb(54, 115, 95));
room("MusicRoom", [-95, 0, 135], rgb(105, 74, 135));
room("ArtRoom", [125, 0, 135], rgb(155, 95, 70));
room("BroadcastRoom", [225, 0, 110], rgb(70, 120, 155));
room("HealthRoom", [-165, 0, -145], rgb(130, 80, 100));

part("Gym_Floor", [86, 0.16, 58], [-260, 0.82, -145], rgb(88, 96, 108), { material: "WoodPlanks" });
wall("Gym_SouthWall", [-260, 6, -174], [86, 12, 2]);
wall("Gym_EastWall", [-217, 6, -158], [2, 12, 32]);
wall("Gym_WestWall", [-303, 6, -158], [2, 12, 32]);
for (let i = 0; i < 4; i += 1) part(`Gym_Bleacher_${i}`, [34, 1, 4], [-290, 1 + i * 1.1, -168 + i * 4], rgb(85, 95, 115), { material: "Metal" });
part("Gym_CourtLine", [62, 0.1, 2], [-260, 1, -145], rgb(255, 235, 130), { material: "Neon", canCollide: false });
part("BasketballHoop_A", [6, 6, 0.5], [-300, 6, -145], rgb(255, 135, 45), { material: "Neon" });
part("BasketballHoop_B", [6, 6, 0.5], [-220, 6, -145], rgb(255, 135, 45), { material: "Neon" });

part("OutdoorYard", [120, 0.12, 70], [115, 0.9, -35], rgb(70, 135, 70), { material: "Grass" });
tree("YardTree_A", 80, -50, 1.2);
tree("YardTree_B", 130, -70, 1);
tree("YardTree_C", 160, -20, 1.1);

part("Library_Floor", [32, 0.08, 20], [-12, 0.62, 31], rgb(80, 72, 105), { material: "WoodPlanks" });
[-16, -8, 0].forEach((x, i) => shelf(`LibraryShelf_${i}`, x, 31));
shelf("LibraryShelf_SideA", -20, 35);
shelf("LibraryShelf_SideB", 3, 35);

part("Cafeteria_Floor", [34, 0.08, 20], [24, 0.62, -31], rgb(92, 78, 64), { material: "CeramicTiles" });
[9, 22, 35].forEach((x, i) => {
  part(`CafeteriaTable_${i}`, [7, 0.45, 2.4], [x, 2.2, -31], rgb(110, 72, 46), { material: "Wood" });
  part(`CafeteriaBenchA_${i}`, [7, 0.35, 0.8], [x, 1.7, -33.1], rgb(75, 85, 95), { material: "Metal" });
  part(`CafeteriaBenchB_${i}`, [7, 0.35, 0.8], [x, 1.7, -28.9], rgb(75, 85, 95), { material: "Metal" });
});
part("VendingMachine", [3.2, 6, 2], [39, 3.4, -36], rgb(210, 45, 65));
part("VendingMachine_Screen", [2, 2, 0.18], [39, 4.5, -37.05], rgb(80, 220, 255), { material: "Neon" });

part("GeneratorRoom_Floor", [52, 0.1, 36], [230, 0.7, -145], rgb(55, 105, 135), { material: "Metal" });
part("EmergencyGenerator", [6, 4, 4], [230, 3, -145], rgb(65, 170, 230), { material: "Metal" });
part("GeneratorCoil", [4.6, 1.1, 1.1], [230, 4.5, -147.2], rgb(120, 230, 255), { material: "Neon" });
part("BrokenPipe_A", [36, 0.7, 0.7], [230, 8.5, -165], rgb(80, 88, 92), { material: "Metal" });
part("BrokenPipe_B", [0.7, 0.7, 28], [255, 8.3, -145], rgb(80, 88, 92), { material: "Metal" });

[-44, -37, 13, 20, 44].forEach((x, i) => locker(`MainLocker_${i}`, x, i < 2 || i === 4 ? -7 : 9));
for (let i = 1; i <= 6; i += 1) locker(`NorthLocker_${i}`, -220 + (i - 1) * 72, 124);
for (let i = 1; i <= 5; i += 1) locker(`SouthLocker_${i}`, -185 + (i - 1) * 85, -149);

[
  [-54, 28], [-46, 29], [-56, 20], [-48, 20],
  [-10, 33], [25, 33], [33, 33], [24, 28], [16, -33],
].forEach(([x, z], i) => desk(`Desk_${i}`, x, z));
[
  [-40, 21], [-52, 19], [-44, 28], [8, -30], [34, 31], [28, 28],
  [-200, 116], [-115, 116], [-30, 116], [55, 116], [-150, -138], [-50, -138], [50, -138],
].forEach(([x, z], i) => chair(`Chair_${i}`, x, z));

zone("StartRoom_Zone", [-46, 2.5, 25], [36, 4, 20], rgb(70, 115, 200));
zone("Science_Zone", [-185, 2.5, 135], [56, 5, 38], rgb(54, 184, 132));
zone("Music_Zone", [-95, 2.5, 135], [56, 5, 38], rgb(148, 72, 224));
zone("Art_Zone", [125, 2.5, 135], [56, 5, 38], rgb(224, 115, 46));
zone("Broadcast_Zone", [225, 2.5, 110], [56, 5, 38], rgb(56, 132, 224));
zone("Health_Zone", [-165, 2.5, -145], [56, 5, 38], rgb(224, 64, 115));
zone("Gym_Zone", [-260, 2.5, -145], [86, 5, 58], rgb(107, 128, 166));
zone("Yard_Zone", [115, 2.5, -35], [120, 5, 70], rgb(56, 173, 64));
zone("Generator_Zone", [230, 2, -145], [52, 4, 36], rgb(56, 158, 224));

marker("Landmark_Start", [-52, 27.5, 22], rgb(46, 132, 255));
marker("Landmark_NorthWing", [-185, 27.5, 120], rgb(140, 71, 255));
marker("Landmark_SouthWing", [135, 27.5, -145], rgb(255, 132, 38));
marker("Landmark_Gym", [-260, 27.5, -145], rgb(255, 209, 26));
marker("Landmark_Exit", [305, 32.5, 0], rgb(20, 255, 97), [10, 65, 10]);
marker("Landmark_Center", [0, 25, 0], rgb(0, 224, 255), [6, 50, 6]);

part("PlayerSpawn_Preview", [8, 1, 8], [-52, 1.5, 23], rgb(70, 115, 200), { material: "Neon", canCollide: false });
part("EscapeExit_Preview", [14, 14, 24], [305, 7, 0], rgb(13, 255, 97), {
  material: "Neon",
  transparency: 0.2,
  canCollide: false,
});
part("ExitLock_Preview", [10, 10, 18], [305, 5, 0], rgb(255, 38, 38), {
  transparency: 0.45,
  canCollide: false,
});
part("Fuse_1_Preview", [5, 5, 5], [-190, 4, 135], rgb(255, 224, 13), { material: "Neon", shape: "Ball", canCollide: false });
part("Fuse_2_Preview", [5, 5, 5], [135, 4, -155], rgb(255, 224, 13), { material: "Neon", shape: "Ball", canCollide: false });
part("Fuse_3_Preview", [5, 5, 5], [255, 4, 110], rgb(255, 224, 13), { material: "Neon", shape: "Ball", canCollide: false });
part("Ghost_Preview", [5, 7, 5], [6, 4, 28], rgb(199, 242, 255), { material: "ForceField", transparency: 0.3, canCollide: false });
part("Monster_Preview", [6, 7, 6], [-6, 4, 0], rgb(230, 56, 31), { material: "Neon", canCollide: false });

const model = {
  className: "Model",
  children,
};

fs.writeFileSync(
  path.join(__dirname, "..", "src", "Workspace", "StaticPreviewMap.model.json"),
  `${JSON.stringify(model, null, 2)}\n`,
);

console.log(`Wrote ${children.length} preview parts`);
