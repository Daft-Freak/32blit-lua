#include "main.hpp"
#include "lua/lua.hpp"
#include "luablitlib.hpp"

using namespace blit;

lua_State *L;
bool has_update = true;
bool has_render = true;

void init() {
    set_screen_mode(ScreenMode::hires);
    screen.pen = Pen(0, 0, 0, 255);
    screen.clear();

    L = luaL_newstate();
    luaL_openlibs(L);
    luaL_requiref(L, "blit", luaopen_blit, 1);
    lua_blit_update_state(L);

    auto launchPath = blit::get_launch_path();
    if(!launchPath) {
        launchPath = "main.lua";
    }
    luaL_loadfile(L, launchPath);

    // Super important priming call that makes stuff not explode
    if(lua_pcall(L, 0, 0, 0) != 0){
        blit::debugf("Error loading %s: %s\n", launchPath, lua_tostring(L, -1));
    }

    lua_getglobal(L, "init");
    if(lua_isfunction(L, lua_gettop(L))){
        if(lua_pcall(L, 0, 0, 0) != 0){
            blit::debugf("Error running function `init`: %s\n", lua_tostring(L, -1));
        }
    }
    lua_gc(L, LUA_GCCOLLECT, 0);

    lua_getglobal(L, "update");
    if(!lua_isfunction(L, lua_gettop(L))){
        blit::debugf("Error `update` is not defined\n");
        has_update = false;
    }

    lua_getglobal(L, "render");
    if(!lua_isfunction(L, lua_gettop(L))){
        blit::debugf("Error `render` is not defined\n");
        has_render = false;
    }

    lua_gc(L, LUA_GCSETPAUSE, 170);
}

void render(uint32_t time) {
    if(!has_render) return;
    uint32_t ms_start = now();
    lua_getglobal(L, "render");
    lua_pushnumber(L, time);
    if(lua_pcall(L, 1, 0, 0) != 0){
        blit::debugf("Error running function `render`: %s\n", lua_tostring(L, -1));
    }
    lua_gc(L, LUA_GCCOLLECT, 0);
    uint32_t ms_end = now();

    // draw FPS meter
    screen.alpha = 255;
    screen.pen = Pen(255, 255, 255, 100);
    screen.rectangle(Rect(1, 120 - 10, 12, 9));
    screen.pen = Pen(255, 255, 255, 200);
    std::string fms = std::to_string(ms_end - ms_start);
    screen.text(fms, minimal_font, Rect(3, 120 - 9, 10, 16));

    const int block_size = 3;
    for (uint32_t i = 0; i < (ms_end - ms_start); i++) {
        screen.pen = Pen(i * 5, 255 - (i * 5), 0);
        screen.rectangle(Rect(i * (block_size + 1) + 1 + 13, screen.bounds.h - block_size - 1, block_size, block_size));
    }
}

void update(uint32_t time) {
    if(!has_update) return;
    lua_blit_update_state(L);
    lua_getglobal(L, "update");
    lua_pushnumber(L, time);
    if(lua_pcall(L, 1, 0, 0) != 0){
        blit::debugf("Error running function `update`: %s\n", lua_tostring(L, -1));
    }
}
