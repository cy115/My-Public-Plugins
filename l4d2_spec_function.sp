#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <pause>

int
    g_iLight[MAXPLAYERS + 1];

bool
    g_bIsGameActive = false,
    g_bAllowLight[MAXPLAYERS + 1];

float
    g_fTagTime[MAXPLAYERS + 1],
    g_fLastImpuse[MAXPLAYERS + 1],
    g_fChangeName[MAXPLAYERS + 1];

ConVar
    g_hEnabledAllTalk;

enum struct TeamTag {
    char originName[MAX_NAME_LENGTH];
    char preTag[16];
    char postTag[16];

    void InitTags() {
        this.preTag[0] = '\0';
        this.postTag[0] = '\0';
    }

    void GetOriginName(int client, const char[] name) {
        FormatEx(this.originName, sizeof(this.originName), name);
    }
}

TeamTag
    tTagPlayer[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "Spec Function",
    author = "Hitomi",
    description = "一些给旁观更好观战体验的功能",
    version = "1.0",
    url = "https://github.com/cy115/"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_light", Cmd_Light);
    RegConsoleCmd("sm_tag", Cmd_Tag);
    RegConsoleCmd("sm_tt", Cmd_Print);

    g_hEnabledAllTalk = CreateConVar("spec_function_talk", "0", "是否在游戏进行时阻断旁观发送全体消息[0 = 否/1 = 是].");

    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("player_changename", Event_PlayerChangename);
    HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);

    AddCommandListener(Event_SayCommand, "say");
}

public void OnClientPutInServer(int client)
{
    g_fTagTime[client] = 0.0;
    g_fLastImpuse[client] = 0.0;
    g_fChangeName[client] = 0.0;

    if (strlen(tTagPlayer[client].originName) == 0) {
        char name[MAX_NAME_LENGTH];
        GetEntPropString(client, Prop_Data, "m_szNetname", name, sizeof(name));
        tTagPlayer[client].GetOriginName(client, name);
    }
    else {
        ApplayTeamTags(client);
    }
}

Action Cmd_Print(int client, int args)
{
    CPrintToChat(client, "原名: %s\n前缀: %s\n后缀: %s", tTagPlayer[client].originName, tTagPlayer[client].preTag, tTagPlayer[client].postTag);

    return Plugin_Handled;
}

Action Cmd_Light(int client, int args)
{
    if (!IsValidClient(client) || GetClientTeam(client) != 1) {
        return Plugin_Handled;
    }

    g_bAllowLight[client] = !g_bAllowLight[client];
    if (g_bAllowLight[client]) {
        CreateLightForSpecatotor(client);
    }
    else {
        DestroySpecatotorLight(client);
    }

    return Plugin_Handled;
}

Action Cmd_Tag(int client, int args)
{
    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }

    if (args == 0) {
        RemoveTeamTags(client);
        return Plugin_Handled;
    }
    else if (args != 2) {
        CPrintToChat(client, "{red}[{default}SF{red}] {default}队标指令用法:");
        CPrintToChat(client, "┌用法: {red}!tag {default}<{olive}前缀{default}> <{olive}后缀{default}>");
        CPrintToChat(client, "└位置: 只需要前缀或后缀只需要将另外一个留空即可");
        return Plugin_Handled;
    }

    char tag1[16], tag2[16];
    GetCmdArg(1, tag1, sizeof(tag1));
    GetCmdArg(2, tag2, sizeof(tag2));
    ApplayTeamTags(client, tag1, tag2);

    return Plugin_Handled;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsGameActive = false;
}

void Event_PlayerChangename(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (GetGameTime() > g_fTagTime[client]) {
        char sName[MAX_NAME_LENGTH];
        event.GetString("newname", sName, sizeof(sName));
        tTagPlayer[client].GetOriginName(client, sName);
    }

    if (strlen(tTagPlayer[client].preTag) == 0 && strlen(tTagPlayer[client].postTag) == 0) {
        return;
    }

    if (GetGameTime() <= g_fChangeName[client]) {
        return;
    }

    ApplayTeamTags(client);
    g_fChangeName[client] = GetGameTime() + 3.0;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int
        client = GetClientOfUserId(event.GetInt("userid")),
        team = event.GetInt("team"),
        oldteam = event.GetInt("oldteam");

    if (!IsValidClient(client) || IsFakeClient(client) || 
        team == oldteam || oldteam == 0) {
        return;
    }

    DestroySpecatotorLight(client);
    if (team != 1) {
        return;
    }

    CPrintToChat(client, "{olive}[{default}SF{olive}] {default}输入{green}!light{default}或按{green}F键{default}来开关旁观灯光.");
    if (g_bAllowLight[client]) {
        CreateLightForSpecatotor(client);
    }
}

// 旁观灯光 & 禁言功能
void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsGameActive = false;
}

Action Event_SayCommand(int client, const char[] command, int args)
{
    if (!GetConVarBool(g_hEnabledAllTalk)) {
        return Plugin_Continue;
    }

    if (!g_bIsGameActive || args == 0 || !IsValidClient(client)) {
        return Plugin_Continue;
    }

    char text[192];
    text[0] = '\0';
    GetCmdArgString(text, 192);
    FakeClientCommand(client, "say_team %s", text);

    return Plugin_Handled;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    g_bIsGameActive = true;

    return Plugin_Continue;
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    g_bIsGameActive = false;

    return Plugin_Continue;
}

public void OnPause()
{
    g_bIsGameActive = false;
}

public void OnUnpause()
{
    g_bIsGameActive = true;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
    if (GetClientTeam(client) != 1) {
        return Plugin_Continue;
    }

    if (impulse == 100 && GetGameTime() > g_fLastImpuse[client]) {
        g_bAllowLight[client] = !g_bAllowLight[client];
        if (g_bAllowLight[client]) {
            CreateLightForSpecatotor(client);
        }
        else {
            DestroySpecatotorLight(client);
        }

        g_fLastImpuse[client] = GetGameTime() + 1.0;
    }

    return Plugin_Continue;
}
void CreateLightForSpecatotor(int spec)
{
    if (g_bAllowLight[spec]) {
        int entity = MakeLightDynamic(view_as<float>({ 0.0, 0.0, 10.0 }), view_as<float>({ 0.0, 0.0, 0.0 }), spec);
        DispatchKeyValue(entity, "_light", "255 255 255 255");
        DispatchKeyValue(entity, "brightness", "2");
        g_iLight[spec] = EntIndexToEntRef(entity);
        SDKHook(entity, SDKHook_SetTransmit, SetTransmition);
    }
}

void DestroySpecatotorLight(int spec)
{
    int entity = g_iLight[spec];
    g_iLight[spec] = 0;
    if (IsValidEntRef(entity)) {
        AcceptEntityInput(entity, "kill");
    }
}

Action SetTransmition(int entity, int client)
{
    if (g_iLight[client] == EntIndexToEntRef(entity)) {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}

int MakeLightDynamic(const float vOrigin[3], const float vAngles[3], int client)
{
    int entity = CreateEntityByName("light_dynamic");
    if (entity == -1) {
        return 0;
    }

    char sTemp[16];
    Format(sTemp, sizeof(sTemp), "255 255 255 255");
    DispatchKeyValue(entity, "_light", sTemp);
    DispatchKeyValue(entity, "brightness", "1");
    DispatchKeyValueFloat(entity, "spotlight_radius", 48.0);
    DispatchKeyValueFloat(entity, "distance", 255.0);
    DispatchKeyValue(entity, "style", "0");
    DispatchSpawn(entity);
    AcceptEntityInput(entity, "TurnOn");
    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", client);
    TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
    return entity;
}

bool IsValidEntRef(int entity)
{
    if (entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE) {
        return true;
    }

    return false;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

// Tags
void ApplayTeamTags(int client, const char[] tag1 = "", const char[] tag2 = "")
{
    char authId[64];
    if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId))) {
        return;
    }

    bool
        bHasPreTag = strlen(tag1) > 0,
        bHasPostTag = strlen(tag2) > 0;

    char name[MAX_NAME_LENGTH];

    if (bHasPreTag) {
        FormatEx(tTagPlayer[client].preTag, 16, tag1);
    }

    if (bHasPostTag) {
        FormatEx(tTagPlayer[client].postTag, 16, tag2);
    }

    FormatEx(name, sizeof(name), "%s%s%s", tTagPlayer[client].preTag, tTagPlayer[client].originName, tTagPlayer[client].postTag);
    CS_SetClientName(client, name);
    g_fTagTime[client] = GetGameTime() + 3.0;
}

void RemoveTeamTags(int client)
{
    char authId[64];
    if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId))) {
        return;
    }

    char name[MAX_NAME_LENGTH];
    tTagPlayer[client].InitTags();
    FormatEx(name, sizeof(name), tTagPlayer[client].originName);
    CS_SetClientName(client, name);
}

void CS_SetClientName(int client, const char[] name)
{
    SetClientInfo(client, "name", name);
    SetEntPropString(client, Prop_Data, "m_szNetname", name);
}