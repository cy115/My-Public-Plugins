#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <sdktools_sound>

#define WHISPER "buttons/blip2.wav"

public Plugin myinfo =
{
    name = "Whisper to s.b",
    author = "Hitomi",
    description = "对某人私信",
    version = "1.0",
    url = "https://github.com/cy115/"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_to", Cmd_WhisperToSB);
}

public void OnMapStart()
{
    PrecacheSound(WHISPER);
}

public Action Cmd_WhisperToSB(int client, int args)
{
    if (args != 2) {
        CReplyToCommand(client, "{red}Usage{default}: {red}!to {default}<{red}name{default}> <{red}text{default}>");
        return Plugin_Handled;
    }

    char
        targetName[MAX_TARGET_LENGTH],
        text[512];

    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, text, sizeof(text));
    int target = FindTarget(client, targetName, false, false);
    if (IsFakeClient(target) || !IsClientInGame(target)) {
        CReplyToCommand(client, "{red}不是{default}，{red}哥们{default}，{red}你跟假人说悄悄话啊{default}?");
        return Plugin_Handled;
    }

    if (target == client) {
        CReplyToCommand(client, "{red}你也是自言自语上了{default}?");
        return Plugin_Handled;
    }

    CPrintToChat(client, "{green}[{default}!{green}] {default}你单独对 {olive}%N {default}说: {green}%s", target, text);
    CPrintToChat(target, "{green}[{default}!{green}] {olive}%N {default}单独对你说: {green}%s", client, text);
    EmitSoundToClient(client, WHISPER);
    EmitSoundToClient(target, WHISPER);
    return Plugin_Handled;
}