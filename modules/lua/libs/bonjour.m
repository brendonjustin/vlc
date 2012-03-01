/*****************************************************************************
 * bonjour.m: Bonjour service advertisement support
 *****************************************************************************
 * Copyright (C) 2012 the VideoLAN team and authors
 * $Id$
 *
 * Authors: Brendon Justin <brendonjustin@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/*****************************************************************************
 * Preamble
 *****************************************************************************/

#include "../vlc.h"
#include "../libs.h"

#import <Cocoa/Cocoa.h>

/*****************************************************************************
 * BonjourAdvertiser Helper Class Definition
 *****************************************************************************/

@interface BonjourAdvertiser : NSObject <NSNetServiceDelegate>
{
    NSNetService *m_service;
    NSMutableArray *m_services;
    NSMutableDictionary *m_txtRecordDict;
}

- (void)setDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name andPort:(int)port;
- (void)addTXTRecordWithKey:(NSString *)key andValue:(NSString *)value;
- (void)register;
- (void)stop;

@end

/*****************************************************************************
 * BonjourAdvertiser Helper Class Implementation
 *****************************************************************************/

@implementation BonjourAdvertiser

- (id)init 
{
    if ( (self = [super init]) ) {
        m_service = nil;
        m_services = [[NSMutableArray alloc] init];
        m_txtRecordDict = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (void)dealloc
{
    [self stop];
    [m_services release];
    [m_txtRecordDict release];
    [super dealloc];
}

- (void)stop
{
    for ( NSNetService *service in m_services )
    {
        [service stop];
    }
}

- (void)setDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name andPort:(int)port;
{
    if ( m_service ) {
        [m_service release];
    }
    m_service = [[NSNetService alloc] initWithDomain:domain
                                              type:type
                                              name:name port:port];
}

- (void)addTXTRecordWithKey:(NSString *)key andValue:(NSString *)value
{
    [m_txtRecordDict setValue:value forKey:key];
}

- (void)register
{
    if( m_service )
    {
        [m_service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:m_txtRecordDict]];
        [m_service setDelegate:self];
        [m_service publish];
    }
}

#pragma mark -
#pragma mark NSNetServiceDelegate functions

// Sent when the service is successfully published
- (void)netServiceDidPublish:(NSNetService *)netService
{
    [m_services addObject:netService];
}

@end

/*****************************************************************************
 * Local prototypes
 *****************************************************************************/

static int vlclua_bonjour_init( lua_State * );
static int vlclua_bonjour_new_service( lua_State * );
static int vlclua_bonjour_delete( lua_State * );
static int vlclua_bonjour_add_record( lua_State * );
static int vlclua_bonjour_publish_service( lua_State * );

/*****************************************************************************
 * Bonjour Service Advertiser
 *****************************************************************************/
 
static const luaL_Reg vlclua_bonjour_reg[] = {
    { "new_service", vlclua_bonjour_new_service },
    { "add_record", vlclua_bonjour_add_record },
    { "publish_service", vlclua_bonjour_publish_service },
    { NULL, NULL }
};

static int vlclua_bonjour_init( lua_State *L )
{
    BonjourAdvertiser *p_advertiser = [[BonjourAdvertiser alloc] init];
    BonjourAdvertiser **pp_advertiser = lua_newuserdata( L, sizeof( BonjourAdvertiser *) );
    *pp_advertiser = p_advertiser;

    if( luaL_newmetatable( L, "bonjour_advertiser" ) )
    {
        lua_newtable( L );
        luaL_register( L, NULL, vlclua_bonjour_reg );
        lua_setfield( L, -2, "__index" );
        lua_pushcfunction( L, vlclua_bonjour_delete );
        lua_setfield( L, -2, "__gc" );
    }

    lua_setmetatable( L, -2 );
    return 1;
}

static int vlclua_bonjour_new_service( lua_State *L )
{
    NSString *domain, *type, *name;
    int port;

    const char *psz_domain = luaL_checkstring( L, 2 );
    const char *psz_type = luaL_checkstring( L, 3 );
    const char *psz_hostname = luaL_checkstring( L, 4 );
    const char *psz_port = luaL_checkstring( L, 5 );

    domain = [NSString stringWithUTF8String:psz_domain];
    type = [NSString stringWithUTF8String:psz_type];
    name = [NSString stringWithUTF8String:psz_hostname];
    port = [[NSString stringWithUTF8String:psz_port] intValue];
    
    BonjourAdvertiser **pp_advertiser = (BonjourAdvertiser **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    [*pp_advertiser setDomain:domain type:type name:name andPort:port];

    return 1;
}

static int vlclua_bonjour_delete( lua_State *L )
{
    BonjourAdvertiser **pp_advertiser = (BonjourAdvertiser **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    [*pp_advertiser stop];
    [*pp_advertiser release];
    return 0;
}

static int vlclua_bonjour_add_record( lua_State *L )
{
    NSString *value, *key;
    BonjourAdvertiser **pp_advertiser = (BonjourAdvertiser **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    const char *psz_key = luaL_checkstring( L, 2 );
    const char *psz_value = luaL_checkstring( L, 3 );

    value = [NSString stringWithUTF8String:psz_value];
    key = [NSString stringWithUTF8String:psz_key];
    [*pp_advertiser addTXTRecordWithKey:key andValue:value];

    return 1;
}

static int vlclua_bonjour_publish_service( lua_State *L )
{
    BonjourAdvertiser **pp_advertiser = (BonjourAdvertiser **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    [*pp_advertiser register];

    return 1;
}

/*****************************************************************************
 *
 *****************************************************************************/
void luaopen_bonjour( lua_State *L )
{
    lua_pushcfunction( L, vlclua_bonjour_init );
    lua_setfield( L, -2, "bonjour" );
}
