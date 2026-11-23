"""Generate the chef animation set (ANIMATION_DESIGN.md) on a Mixamo-rigged GLB and export it for Godot.

Run (one character per Blender session, so node names stay identical between chefs):
    blender -b --factory-startup --python art/blender/chef_anims.py -- apis
    blender -b --factory-startup --python art/blender/chef_anims.py -- tony

Options after the character name:
    --sheet <png>   render a contact sheet of every clip to <png>
    --no-export     skip writing the .glb / .blend

Conventions (Blender world after glTF import): +X = character's left, -Y = front, +Z = up.
Pose ops per bone, applied in order, all expressed in the rest pose frame:
    ("X"|"Y"|"Z", deg)   rotate about a world axis (torso, head, hips)
    ("to", "DOWN"|"UP"|"FWD"|"BACK"|"IN"|"OUT", deg)
                         swing the bone's current direction toward that world direction (arms, legs)
    ("twist", deg)       roll around the bone's current direction
"""

import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FPS = 30
B = "mixamorig:"

# ---------------------------------------------------------------------------------------------
# Personality (ANIMATION_DESIGN.md §2, §4)
# ---------------------------------------------------------------------------------------------

STYLES = {
    "apis": {
        "tempo": {"idle": 1.0, "chop": 1.0, "busy": 1.0, "victory": 1.0, "lose": 1.0},
        "amp": {"idle": 1.0, "chop": 1.0, "busy": 1.0, "victory": 1.0, "lose": 1.0},
        "base": {"Spine": [("X", 4)]},
    },
    "tony": {
        "tempo": {"idle": 1.2, "chop": 0.85, "busy": 1.1, "victory": 1.0, "lose": 1.0},
        # victory/lose have their own Tony poses, so they are not amplified again
        "amp": {"idle": 1.3, "chop": 1.15, "busy": 1.1, "victory": 1.0, "lose": 1.0},
        # Slouch with the belly pushed out: pelvis-up spine leans back, upper spine forward, head stays level.
        "base": {
            "Spine": [("X", -6)],
            "Spine2": [("X", 10)],
            "Neck": [("X", -4)],
            "LeftShoulder": [("to", "DOWN", 6)],
            "RightShoulder": [("to", "DOWN", 6)],
        },
    },
}

DIRS = {
    "DOWN": Vector((0, 0, -1)),
    "UP": Vector((0, 0, 1)),
    "FWD": Vector((0, -1, 0)),
    "BACK": Vector((0, 1, 0)),
}


# ---------------------------------------------------------------------------------------------
# Pose helpers
# ---------------------------------------------------------------------------------------------

def arm(side, down=0, fwd=0, out=0, elbow=10, twist=0, hand=0):
    """Ops for one arm. down/fwd/out swing the upper arm from the A-pose; elbow flexes the forearm."""
    s = "Left" if side == "L" else "Right"
    up_ops = []
    if down:
        up_ops.append(("to", "DOWN", down))
    if out:
        up_ops.append(("to", "OUT", out))
    if fwd:
        up_ops.append(("to", "FWD", fwd))
    if twist:
        up_ops.append(("twist", twist if side == "L" else -twist))
    return {
        s + "Arm": up_ops,
        s + "ForeArm": [("flex", elbow)] if elbow else [],
        s + "Hand": [("flex", hand)] if hand else [],
    }


def relaxed_arms(extra_down=0):
    p = {}
    p.update(arm("L", down=32 + extra_down, elbow=12))
    p.update(arm("R", down=32 + extra_down, elbow=12))
    return p


def merge(*dicts):
    out = {}
    for d in dicts:
        for k, v in d.items():
            out[k] = out.get(k, []) + list(v)
    return out


# ---------------------------------------------------------------------------------------------
# Clips. Each returns (frames, loop, keys); key = dict(f=frame, pose=ops, hips=(x,y,z) m, crouch=m, only=bool)
# Frames are authored for Apis tempo; the style tempo scales them.
# ---------------------------------------------------------------------------------------------

def clip_idle(c):
    tony = c == "tony"
    keys = []
    for i, f in enumerate([0, 15, 30, 45, 60]):
        breath = [0, 0.5, 1, 0.5, 0][i]          # inhale peaks at the middle
        sway = [0, 1, 0, -1, 0][i]               # head sway, quarter cycle offset
        pose = merge(
            {"Spine1": [("X", -3 * breath)], "Spine2": [("X", -2 * breath)],
             "Head": [("X", -2 * breath), ("Y", 3 * sway)],
             "LeftShoulder": [("to", "UP", 2 * breath)], "RightShoulder": [("to", "UP", 2 * breath)]},
            relaxed_arms(),
        )
        hips = (0, 0, -0.01 + 0.012 * breath)
        if tony:
            pose = merge(pose, {"Head": [("Y", -6)], "Hips": [("Y", 4)],
                                "LeftUpLeg": [("Y", -4)], "RightUpLeg": [("Y", -4)]})
            # left hand on the hip: arm out and back, elbow bent hard
            pose.update(arm("L", down=10, out=0, fwd=-25, elbow=95, twist=40))
            hips = (-0.012, 0, hips[2])
        keys.append(dict(f=f, pose=pose, hips=hips))
    return 60, True, keys


def clip_chop(c):
    """Three chops per cycle (chop, chop, BIG chop). Whole body drives the knife: lean in and dip on every hit."""
    tony = c == "tony"
    look = 4 if tony else 12

    def left(slide):  # left hand holds the food and steps aside after each cut
        return arm("L", down=22, fwd=48, out=slide, elbow=78, twist=-20, hand=-10)

    def up(slide, big=False):
        lift = 12 if big else 0
        r = arm("R", down=-50 - lift - (12 if tony else 0), fwd=40, elbow=120 + lift, twist=-20, hand=-45)
        body = {"Spine": [("X", -2)], "Spine1": [("X", -2 - lift * 0.3)], "Head": [("X", look - 4)],
                "RightShoulder": [("to", "UP", 16 + lift)], "Spine2": [("Z", 6)]}
        return merge(body, left(slide), r)

    def hit(slide, big=False):
        r = arm("R", down=42, fwd=34, elbow=18, twist=-20, hand=35)
        body = {"Spine": [("X", 10 + (4 if big else 0))], "Spine1": [("X", 8)], "Head": [("X", look + 8)],
                "RightShoulder": [("to", "DOWN", 14)], "LeftShoulder": [("to", "DOWN", 4)], "Spine2": [("Z", -4)]}
        return merge(body, left(slide), r)

    def recoil(slide):
        r = arm("R", down=26, fwd=42, elbow=50, twist=-20, hand=10)
        body = {"Spine": [("X", 7)], "Spine1": [("X", 5)], "Head": [("X", look + 4)]}
        return merge(body, left(slide), r)

    peek = {"Head": [("Z", 22), ("Y", -8)]} if tony else {}  # Tony shows off to the crowd before the big one
    keys = [
        dict(f=0, pose=up(0), hips=(0, 0, 0.004)),
        dict(f=4, pose=hit(0), crouch=0.035, ease="in"),
        dict(f=6, pose=recoil(0), crouch=0.018, ease="out"),
        dict(f=10, pose=up(6), hips=(0, 0, 0.004)),
        dict(f=14, pose=hit(6), crouch=0.035, ease="in"),
        dict(f=16, pose=recoil(6), crouch=0.018, ease="out"),
        dict(f=24, pose=merge(up(12, big=True), peek), hips=(0, 0, 0.012)),
        dict(f=28, pose=hit(12, big=True), crouch=0.055, ease="in"),
        dict(f=31, pose=recoil(12), crouch=0.03, ease="out"),
        dict(f=36, pose=up(0), hips=(0, 0, 0.004)),
    ]
    return 36, True, keys


def clip_busy(c):
    """Grab from the left, drop it in the middle, shake and toss the pan on the right. Hops between stations."""
    turn = 50

    def turned(sign, extra, lean=0.0):
        hip = 0.35 * turn * sign
        body = {"Hips": [("Z", hip), ("Y", 3 * sign)], "LeftUpLeg": [("Z", -hip), ("Y", -3 * sign)],
                "RightUpLeg": [("Z", -hip), ("Y", -3 * sign)],
                "Spine": [("X", 8 + lean), ("Z", 0.35 * turn * sign)], "Spine1": [("Z", 0.3 * turn * sign)],
                "Spine2": [("Y", 3 * sign)]}
        return merge(body, extra)

    def head(yaw, pitch=12):
        return {"Head": [("X", pitch), ("Z", yaw)]}

    work = merge({"Spine": [("X", 10)], "Head": [("X", 12)]},
                 arm("L", down=24, fwd=42, elbow=65), arm("R", down=24, fwd=42, elbow=65))
    drop = merge({"Spine": [("X", 16)], "Spine1": [("X", 4)], "Head": [("X", 18)]},
                 arm("L", down=30, fwd=50, out=-10, elbow=40, hand=20),
                 arm("R", down=30, fwd=50, out=-10, elbow=40, hand=20))
    reach = merge(arm("R", down=0, fwd=70, out=-50, elbow=5, hand=-20), arm("L", down=0, out=25, elbow=45))
    grab = merge(arm("R", down=12, fwd=62, out=-45, elbow=35, hand=35), arm("L", down=5, out=20, elbow=50))
    carry = merge(arm("R", down=20, fwd=55, out=-20, elbow=75, hand=20), arm("L", down=20, fwd=40, elbow=70))

    def pan(push):
        return merge(arm("R", down=18, fwd=45 + push, elbow=85 - push, twist=-10, hand=-15),
                     arm("L", down=10, out=20, elbow=55))

    toss = merge(arm("R", down=-35, fwd=55, elbow=60, twist=-10, hand=-35), arm("L", down=0, out=30, elbow=50))
    side_l = (0.03, 0, -0.01)
    side_r = (-0.03, 0, -0.01)
    keys = [
        dict(f=0, pose=work, hips=(0, 0, -0.008)),
        dict(f=4, pose=head(turn * 0.6, 4), only=True),
        dict(f=9, pose=merge(turned(1, reach, lean=-2), head(turn * 0.5, 6)), hips=side_l, ease="out"),
        dict(f=14, pose=merge(turned(1, grab, lean=8), head(turn * 0.45, 16)), hips=side_l, crouch=0.03, ease="in"),
        dict(f=19, pose=merge(turned(0.4, carry), head(turn * 0.1)), hips=(0.01, 0, 0.03), ease="snap"),
        dict(f=24, pose=drop, crouch=0.035, ease="in"),
        dict(f=27, pose=merge(drop, {"Head": [("X", -4)]}), crouch=0.02, ease="out"),
        dict(f=30, pose=head(-turn * 0.6, 4), only=True),
        dict(f=35, pose=merge(turned(-1, pan(0)), head(-turn * 0.5)), hips=side_r, ease="out"),
        dict(f=39, pose=merge(turned(-1, pan(30)), head(-turn * 0.45, 16)), hips=side_r, crouch=0.015, ease="in"),
        dict(f=43, pose=merge(turned(-1, pan(-10)), head(-turn * 0.5)), hips=side_r, ease="out"),
        dict(f=47, pose=merge(turned(-1, pan(30)), head(-turn * 0.45, 16)), hips=side_r, crouch=0.015, ease="in"),
        dict(f=51, pose=merge(turned(-1, pan(-15)), head(-turn * 0.5)), hips=side_r, crouch=0.03, ease="out"),
        dict(f=55, pose=merge(turned(-1, toss, lean=-12), head(-turn * 0.4, -22)), hips=(-0.03, 0, 0.035), ease="snap"),
        dict(f=61, pose=merge(turned(-1, pan(0)), head(-turn * 0.5, 14)), hips=side_r, crouch=0.035, ease="in"),
        dict(f=66, pose=merge(work, head(0)), hips=(0, 0, 0.015), ease="out"),
        dict(f=72, pose=work, hips=(0, 0, -0.008)),
    ]
    return 72, True, keys


def hand_on_hip():
    return arm("L", down=10, fwd=-28, elbow=100, twist=40)


def clip_victory(c):
    tony = c == "tony"
    neutral = relaxed_arms()
    if not tony:
        fist_hip = arm("L", down=26, fwd=12, elbow=110, twist=30)
        antic = merge({"Spine": [("X", 22)], "Spine1": [("X", 6)], "Head": [("X", 4)]},
                      arm("L", down=50, fwd=-50, elbow=15), arm("R", down=50, fwd=-50, elbow=15))
        tuck = {"LeftUpLeg": [("X", -45)], "RightUpLeg": [("X", -45)], "LeftLeg": [("X", 80)],
                "RightLeg": [("X", 80)], "LeftFoot": [("X", -20)], "RightFoot": [("X", -20)]}
        half_tuck = {k: [(o[0], o[1] * 0.3) for o in ops] for k, ops in tuck.items()}
        jump = merge({"Spine": [("X", -12)], "Spine2": [("X", -8)], "Head": [("X", -22)]}, tuck,
                     arm("L", down=-115, out=10, elbow=8), arm("R", down=-115, out=10, elbow=8))
        fall = merge({"Spine": [("X", -6)], "Head": [("X", -14)]}, half_tuck,
                     arm("L", down=-100, elbow=15), arm("R", down=-100, elbow=15))
        land = merge({"Spine": [("X", 16)], "Spine1": [("X", 6)], "Head": [("X", 2)]},
                     arm("L", down=-55, elbow=45), arm("R", down=-55, elbow=45))
        pump_hi = merge({"Spine": [("X", -10)], "Spine2": [("X", -6)], "Head": [("X", -18), ("Y", -5)]},
                        arm("R", down=-110, fwd=8, elbow=10), fist_hip)
        pump_lo = merge({"Spine": [("X", 6)], "Head": [("X", -4)]},
                        arm("R", down=-45, fwd=12, elbow=100), fist_hip)
        final = merge({"Spine": [("X", -12)], "Spine2": [("X", -8)], "Head": [("X", -18), ("Y", -7)]},
                      arm("R", down=-112, fwd=8, elbow=8), fist_hip)
        keys = [
            dict(f=0, pose=neutral, hips=(0, 0, 0)),
            dict(f=7, pose=antic, crouch=0.09),
            dict(f=13, pose=jump, hips=(0, 0, 0.2), ease="snap"),
            dict(f=19, pose=fall, hips=(0, 0, 0.07)),
            dict(f=22, pose=land, crouch=0.07, ease="in"),
            dict(f=28, pose=pump_hi, hips=(0, 0, 0.02), ease="out"),
            dict(f=33, pose=pump_lo, crouch=0.035, ease="in"),
            dict(f=38, pose=pump_hi, hips=(0, 0, 0.02), ease="out"),
            dict(f=43, pose=pump_lo, crouch=0.035, ease="in"),
            dict(f=50, pose=final, hips=(0, 0, 0.012), ease="out"),
            dict(f=60, pose=final, hips=(0, 0, 0.008)),
        ]
        return 60, False, keys

    # Tony: smug. Little hop, a belly laugh leaning back, then snaps a finger point at the rival.
    hip = hand_on_hip()
    belly = arm("R", down=30, fwd=35, out=-25, elbow=95)
    antic = merge({"Spine": [("X", 12)], "Head": [("X", 6)]}, hip, arm("R", down=40, fwd=-30, elbow=20))
    hop = merge({"Spine": [("X", -14)], "Head": [("X", -16)]}, hip, arm("R", down=-80, out=20, elbow=20))

    def laugh(phase):
        return merge({"Spine": [("X", -16)], "Spine1": [("X", -4 + 4 * phase)], "Spine2": [("X", -6)],
                      "Head": [("X", -22 + 6 * phase), ("Y", -6)],
                      "LeftShoulder": [("to", "UP", 6 * (1 - phase))],
                      "RightShoulder": [("to", "UP", 6 * (1 - phase))]},
                     hip, belly)

    point = merge({"Spine": [("X", -6)], "Spine1": [("Z", -12)], "Head": [("X", -8), ("Y", -10)]},
                  hip, arm("R", down=0, fwd=48, out=40, elbow=0, hand=-10))
    keys = [
        dict(f=0, pose=neutral, hips=(0, 0, 0)),
        dict(f=6, pose=antic, crouch=0.05),
        dict(f=12, pose=hop, hips=(0, 0, 0.09), ease="snap"),
        dict(f=17, pose=merge(hop, {"Spine": [("X", 10)]}), crouch=0.035, ease="in"),
        dict(f=22, pose=laugh(0), hips=(0, 0, 0.01), ease="out"),
        dict(f=25, pose=laugh(1), crouch=0.012),
        dict(f=28, pose=laugh(0), hips=(0, 0, 0.012)),
        dict(f=31, pose=laugh(1), crouch=0.012),
        dict(f=34, pose=laugh(0), hips=(0, 0, 0.012)),
        dict(f=38, pose=laugh(1), crouch=0.01),
        dict(f=44, pose=merge(laugh(0), {"Head": [("X", 6)]}), crouch=0.02),
        dict(f=49, pose=point, hips=(0, 0, 0.01), ease="out"),
        dict(f=60, pose=point, hips=(0, 0, 0.006)),
    ]
    return 60, False, keys


def clip_lose(c):
    tony = c == "tony"
    neutral = relaxed_arms()
    shock = merge({"Spine": [("X", -16)], "Spine2": [("X", -6)], "Head": [("X", -20)],
                   "LeftShoulder": [("to", "UP", 16)], "RightShoulder": [("to", "UP", 16)]},
                  arm("L", down=-35, fwd=45, elbow=105, hand=-20), arm("R", down=-35, fwd=45, elbow=105, hand=-20))

    def tremble(s):
        return merge(shock, {"Head": [("Y", 5 * s)], "Spine2": [("Y", 2 * s)]})

    keys = [
        dict(f=0, pose=neutral, hips=(0, 0, 0)),
        dict(f=5, pose=shock, hips=(0, 0.035, 0.04), ease="snap"),
        dict(f=8, pose=tremble(1), hips=(0, 0.03, 0.02)),
        dict(f=11, pose=tremble(-1), hips=(0, 0.03, 0.02)),
        dict(f=14, pose=tremble(1), hips=(0, 0.03, 0.018)),
        dict(f=17, pose=shock, hips=(0, 0.03, 0.015)),
    ]
    if not tony:
        deflate = merge({"Spine": [("X", 10)], "Spine1": [("X", 4)], "Head": [("X", 12)],
                         "LeftShoulder": [("to", "DOWN", 8)], "RightShoulder": [("to", "DOWN", 8)]},
                        relaxed_arms(extra_down=22))
        slump = merge({"Spine": [("X", 9)], "Spine1": [("X", 4)], "Spine2": [("X", 2)], "Head": [("X", 12)],
                       "LeftShoulder": [("to", "DOWN", 14)], "RightShoulder": [("to", "DOWN", 14)]},
                      arm("L", down=55, fwd=22, elbow=5), arm("R", down=55, fwd=22, elbow=5))
        sigh_in = merge(slump, {"Spine2": [("X", -6)], "Head": [("X", -6)],
                                "LeftShoulder": [("to", "UP", 10)], "RightShoulder": [("to", "UP", 10)]})
        final = merge(slump, {"Head": [("X", 6), ("Y", 5)], "Spine": [("X", 2)]})
        keys += [
            dict(f=30, pose=deflate, crouch=0.04),
            dict(f=40, pose=slump, crouch=0.11, ease="in"),
            dict(f=45, pose=slump, crouch=0.095, ease="out"),
            dict(f=55, pose=sigh_in, crouch=0.09),
            dict(f=66, pose=final, crouch=0.105, ease="in"),
            dict(f=72, pose=final, crouch=0.105),
        ]
        return 72, False, keys

    # Tony: grabs his head, shakes it in denial, drops to his knees and pounds the floor.
    def grab(yaw):
        return merge({"Spine": [("X", -6)], "Spine2": [("Z", yaw * 0.5)], "Head": [("X", 8), ("Z", yaw)]},
                     arm("L", down=-65, fwd=42, elbow=135), arm("R", down=-65, fwd=42, elbow=135))

    kneel = merge({"Spine": [("X", 14)], "Spine1": [("X", 6)], "Head": [("X", 12)]},
                  arm("L", down=40, fwd=30, elbow=35), arm("R", down=40, fwd=30, elbow=35))
    pound_up = merge({"Spine": [("X", 6)], "Head": [("X", 6)]},
                     arm("L", down=-20, fwd=55, elbow=90), arm("R", down=-20, fwd=55, elbow=90))
    pound = merge({"Spine": [("X", 30)], "Spine1": [("X", 8)], "Head": [("X", 10)]},
                  arm("L", down=60, fwd=45, elbow=10, hand=20), arm("R", down=60, fwd=45, elbow=10, hand=20))
    keys += [
        dict(f=22, pose=grab(0), crouch=0.015, ease="out"),
        dict(f=27, pose=grab(18), crouch=0.015),
        dict(f=32, pose=grab(-18), crouch=0.015),
        dict(f=37, pose=grab(12), crouch=0.015),
        dict(f=43, pose=kneel, kneel=True, ease="in"),
        dict(f=47, pose=merge(kneel, {"Spine": [("X", -6)]}), kneel=True, ease="out"),
        dict(f=52, pose=pound_up, kneel=True),
        dict(f=56, pose=pound, kneel=True, ease="in"),
        dict(f=59, pose=merge(pound, {"Spine": [("X", -6)]}), kneel=True, ease="out"),
        dict(f=63, pose=pound, kneel=True, ease="in"),
        dict(f=72, pose=merge(pound, {"Head": [("X", 6), ("Y", 5)]}), kneel=True),
    ]
    return 72, False, keys


CLIPS = [("idle", clip_idle), ("chop", clip_chop), ("busy", clip_busy), ("victory", clip_victory), ("lose", clip_lose)]


# ---------------------------------------------------------------------------------------------
# Rig math
# ---------------------------------------------------------------------------------------------

class Rig:
    def __init__(self, arm_obj):
        self.obj = arm_obj
        W = arm_obj.matrix_world.to_3x3()
        self.R = {}      # bone rest orientation in world (quaternion)
        self.dir = {}    # bone rest direction in world (unit)
        for b in arm_obj.data.bones:
            m = W @ b.matrix_local.to_3x3()
            self.R[b.name] = m.to_quaternion()
            self.dir[b.name] = (W @ (b.tail_local - b.head_local)).normalized()
        self.hips_h = (arm_obj.matrix_world @ arm_obj.data.bones[B + "Hips"].head_local).z
        self.k = self.hips_h / 0.248   # Apis hip height is the authoring reference
        # leg geometry for the crouch solver (left leg; rig is near-symmetric)
        bones = arm_obj.data.bones
        hip = W @ bones[B + "LeftUpLeg"].head_local
        knee = W @ bones[B + "LeftLeg"].head_local
        ankle = W @ bones[B + "LeftFoot"].head_local
        self.L1 = (knee - hip).length
        self.L2 = (ankle - knee).length
        self.h0 = hip.z - ankle.z

    def side_dir(self, bone, name):
        if name in DIRS:
            return DIRS[name]
        left = "Left" in bone
        out = Vector((1, 0, 0)) if left else Vector((-1, 0, 0))
        return out if name == "OUT" else -out

    def world_delta(self, bone, ops):
        """Compose ops into one world-frame rotation applied at rest."""
        q = Quaternion()
        d0 = self.dir[bone]
        for op in ops:
            d = q @ d0
            if op[0] in ("X", "Y", "Z"):
                axis = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[op[0]]
                step = Quaternion(axis, math.radians(op[1]))
            elif op[0] == "to":
                target = self.side_dir(bone, op[1])
                axis = d.cross(target)
                if axis.length < 1e-6:
                    continue
                step = Quaternion(axis.normalized(), math.radians(op[2]))
            elif op[0] == "flex":
                # hinge fixed in the parent's frame: bends the rest direction toward the front
                axis = d0.cross(DIRS["FWD"])
                if axis.length < 1e-6:
                    axis = Vector((1, 0, 0))
                step = Quaternion(axis.normalized(), math.radians(op[1]))
            elif op[0] == "twist":
                step = Quaternion(d, math.radians(op[1]))
            else:
                raise ValueError(op)
            q = step @ q
        return q

    def local(self, bone, world_q):
        R = self.R[bone]
        return R.inverted() @ world_q @ R

    def local_loc(self, bone, v):
        return self.R[bone].inverted() @ Vector(v)

    def crouch_ops(self, drop):
        """Planar two-bone IK: lower the hips by `drop` m with feet planted and flat."""
        def angles(h):
            h = max(min(h, self.L1 + self.L2 - 1e-5), abs(self.L1 - self.L2) + 1e-4)
            a = math.acos((self.L1 ** 2 + h ** 2 - self.L2 ** 2) / (2 * self.L1 * h))
            b = math.acos((self.L2 ** 2 + h ** 2 - self.L1 ** 2) / (2 * self.L2 * h))
            return a, b
        a0, b0 = angles(self.h0)
        a1, b1 = angles(self.h0 - drop)
        da, db = math.degrees(a1 - a0), math.degrees(b1 - b0)
        ops = {}
        for s in ("Left", "Right"):
            ops[s + "UpLeg"] = [("X", -da)]          # thigh forward
            ops[s + "Leg"] = [("X", da + db)]        # knee back
            ops[s + "Foot"] = [("X", -db)]           # keep the sole flat
        return ops

    def kneel_ops(self):
        ops = {}
        for s in ("Left", "Right"):
            ops[s + "UpLeg"] = [("X", -8)]
            ops[s + "Leg"] = [("X", 100)]
            ops[s + "Foot"] = [("X", 30)]
        return ops, self.L2 * 0.95


# ---------------------------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------------------------

def scale_ops(ops, amp):
    out = []
    for op in ops:
        if op[0] == "to":
            out.append((op[0], op[1], op[2] * amp))
        else:
            out.append((op[0], op[1] * amp))
    return out


def build_clip(rig, char, name, fn):
    style = STYLES[char]
    frames, loop, keys = fn(char)
    tempo = style["tempo"][name]
    amp = style["amp"][name]
    ease_at = {}  # frame of the key a segment STARTS at -> easing of that segment
    arm_obj = rig.obj
    ad = arm_obj.animation_data or arm_obj.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad.action = act

    # every bone touched anywhere in the clip (plus base posture) is keyed on every full key
    touched = set(style["base"].keys()) | {"Hips"}
    for k in keys:
        touched |= set(k["pose"].keys())
        if k.get("crouch") or k.get("kneel"):
            touched |= {s + p for s in ("Left", "Right") for p in ("UpLeg", "Leg", "Foot")}
    touched = sorted(touched)

    prev = {}
    last_full = None
    for k in keys:
        f = round(k["f"] * tempo) + 1
        if not k.get("only"):
            if k.get("ease") and last_full is not None:
                ease_at[last_full] = k["ease"]
            last_full = f
        pose = {b: scale_ops(o, amp) for b, o in k["pose"].items()}
        hips = Vector(k.get("hips", (0, 0, 0))) * amp * rig.k
        if k.get("crouch"):
            pose = merge(pose, rig.crouch_ops(k["crouch"] * amp * rig.k))
            hips = hips + Vector((0, 0, -k["crouch"] * amp * rig.k))
        if k.get("kneel"):
            kops, drop = rig.kneel_ops()
            pose = merge(pose, kops)
            hips = hips + Vector((0, 0, -drop))
        bones = sorted(pose.keys()) if k.get("only") else touched
        for short in bones:
            name_b = B + short
            pb = arm_obj.pose.bones[name_b]
            ops = style["base"].get(short, []) + pose.get(short, [])
            ql = rig.local(name_b, rig.world_delta(name_b, ops))
            if name_b in prev and prev[name_b].dot(ql) < 0:
                ql.negate()
            prev[name_b] = ql
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = ql
            pb.keyframe_insert("rotation_quaternion", frame=f, group=name_b)
            if short == "Hips" and not k.get("only"):
                pb.location = rig.local_loc(name_b, hips)
                pb.keyframe_insert("location", frame=f, group=name_b)

    # Easing of the segment arriving at a key ("ease" on that key):
    #   "in"   accelerate into the key (strikes, landings)
    #   "out"  overshoot and settle (arrivals, poses that pop)
    #   "snap" leave fast, settle slow (surprise reactions)
    modes = {"in": ("CUBIC", "EASE_IN"), "out": ("BACK", "EASE_OUT"), "snap": ("EXPO", "EASE_OUT")}
    for fc in action_fcurves(act, ad):
        for kp in fc.keyframe_points:
            mode = ease_at.get(int(round(kp.co.x)))
            if mode:
                kp.interpolation, kp.easing = modes[mode]
                if mode == "out":
                    kp.back = 1.2

    end = round(frames * tempo) + 1
    act.frame_range = (1, end)
    act.use_frame_range = True
    act.use_cyclic = loop

    # stash in the NLA so the exporter (Actions mode) sees every clip
    track = ad.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    track.mute = True
    ad.action = None
    return act, end, loop


def action_fcurves(act, ad):
    """F-curves of an action, for both legacy and layered (slotted) actions."""
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    from bpy_extras import anim_utils
    cb = anim_utils.action_get_channelbag_for_slot(act, ad.action_slot)
    return list(cb.fcurves) if cb else []


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


# ---------------------------------------------------------------------------------------------
# Contact sheet
# ---------------------------------------------------------------------------------------------

def render_sheet(arm_obj, clips, path, cols=8, size=200, view="three"):
    import numpy as np
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("w") if not scene.world else scene.world
    scene.world = world
    world.color = (0.18, 0.19, 0.22)
    cam_data = bpy.data.cameras.new("sheet_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.25
    cam = bpy.data.objects.new("sheet_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (1.1, -2.6, 0.75) if view == "three" else (0, -3.0, 0.5)
    look = Vector((0, 0, 0.48)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    ad = arm_obj.animation_data
    tmp = os.path.join(os.path.dirname(path), "_frame.png")
    rows = []
    for name, act, end, _loop in clips:
        ad.action = act
        row = []
        for i in range(cols):
            f = 1 + round(i * (end - 1) / (cols - 1))
            scene.frame_set(f)
            scene.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(tmp, check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
            bpy.data.images.remove(img)
            row.append(px)
        rows.append(np.concatenate(row, axis=1))
        ad.action = None
    sheet = np.concatenate(rows[::-1], axis=0)  # pixels are bottom-up: first clip ends on top
    h, w = sheet.shape[:2]
    out = bpy.data.images.new("sheet", w, h)
    out.pixels = sheet.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    os.remove(tmp)
    bpy.data.objects.remove(cam)


# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    char = argv[0] if argv else "apis"
    sheet = argv[argv.index("--sheet") + 1] if "--sheet" in argv else None
    do_export = "--no-export" not in argv
    only = argv[argv.index("--clips") + 1].split(",") if "--clips" in argv else None
    cols = int(argv[argv.index("--cols") + 1]) if "--cols" in argv else 8
    view = argv[argv.index("--view") + 1] if "--view" in argv else "three"
    size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 200

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "blender", "src", f"{char}_src.glb"))
    scene = bpy.context.scene
    scene.render.fps = FPS
    arm_obj = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh_obj = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm_obj)
    arm_obj.name = "Armature"
    mesh_obj.name = f"{char}_body"
    rig = Rig(arm_obj)

    clips = []
    for name, fn in CLIPS:
        reset_pose(arm_obj)
        act, end, loop = build_clip(rig, char, name, fn)
        clips.append((name, act, end, loop))
        print(f"CLIP {name}: frames 1-{end} ({(end - 1) / FPS:.2f}s) loop={loop}")
    reset_pose(arm_obj)
    scene.frame_start, scene.frame_end = 1, max(c[2] for c in clips)

    if sheet:
        render_sheet(arm_obj, [c for c in clips if not only or c[0] in only], sheet, cols=cols, view=view, size=size)
        print("SHEET", sheet)

    if do_export:
        blend = os.path.join(ROOT, "art", "blender", f"{char}_anim.blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        bpy.ops.object.select_all(action="DESELECT")
        arm_obj.select_set(True)
        mesh_obj.select_set(True)
        bpy.context.view_layer.objects.active = arm_obj
        out = os.path.join(ROOT, "godot", "assets", "characters", f"{char}.glb")
        bpy.ops.export_scene.gltf(
            filepath=out,
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_animations=True,
            export_animation_mode="ACTIONS",
            export_force_sampling=True,
            export_frame_range=False,
            export_anim_single_armature=True,
            export_reset_pose_bones=True,
            export_cameras=False,
            export_lights=False,
        )
        print("EXPORT", out, "BLEND", blend)


main()
