/*****************************************************************************
 * airplay_bonjour.m: Broadcasts AirPlay support via bonjour
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
 * AirplayAnnouncer Helper Class Definition
 *****************************************************************************/

/*
Port used for AirPlay support. 6002 is the same port that Airplayer uses,
but VLC's HTTP server uses 8080 by default, so that's what is used here.
*/
#define AIRPLAY_PORT 8080

/*
The name by which VLC will identify itself to other AirPlay
devices. @"" will use the system hostname automatically.
*/
#define AIRPLAY_HOSTNAME @"VLC"

@interface AirplayAnnouncer : NSObject <NSNetServiceDelegate>
{
    NSNetService *apService;
    int port;
    NSMutableArray *services;
}

- (void)register_bonjour;
- (void)start;
- (void)stop;

@end

/*****************************************************************************
 * AirplayAnnouncer Helper Class Implementation
 *****************************************************************************/

@implementation AirplayAnnouncer

- (id)init 
{
    if ((self = [super init]))
        //  The port used to receive video
        port = AIRPLAY_PORT;
    return self;
}

- (void)dealloc
{
    [self stop];
    [services release];
    [super dealloc];
}

- (void)start
{
    [self register_bonjour];
}

- (void)stop
{
    for (NSNetService *service in services)
    {
        [service stop];
    }
}

- (void)register_bonjour
{
    apService = [[NSNetService alloc] initWithDomain:@"local."
                                              type:@"_airplay._tcp"
                                              name:AIRPLAY_HOSTNAME port:port];

    NSArray *recordObjs = [NSArray arrayWithObjects:@"00:00:00:00:00:00", @"0x77", @"AppleTV2,1", @"101.10", nil];
    NSArray *recordKeys = [NSArray arrayWithObjects:@"deviceid", @"features", @"model", @"srcvers", nil];

    NSDictionary *txtRecordDict;
    txtRecordDict = [NSDictionary dictionaryWithObjects:recordObjs
                                                forKeys:recordKeys];
    [apService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txtRecordDict]];

    if(apService)
    {
        [apService setDelegate:self];
        [apService publish];
    }
}

#pragma mark -
#pragma mark NSNetServiceDelegate functions

// Sent when the service is successfully published
- (void)netServiceDidPublish:(NSNetService *)netService
{
    [services addObject:netService];
}

@end

/*****************************************************************************
 * Local prototypes
 *****************************************************************************/

static int vlclua_airplay_bonjour_register( lua_State * );
static int vlclua_airplay_bonjour_delete( lua_State * );

/*****************************************************************************
 * AirPlay Support Broadcaster
 *****************************************************************************/
 
static int vlclua_airplay_bonjour_register( lua_State *L )
{
	vlc_object_t *p_this = vlclua_get_this( L );
	AirplayAnnouncer *p_announcer = [[AirplayAnnouncer alloc] init];
    [p_announcer start];

    AirplayAnnouncer **pp_announcer = lua_newuserdata( L, sizeof( AirplayAnnouncer *) );
    *pp_announcer = p_announcer;

    if( luaL_newmetatable( L, "airplay_bonjour_announcer" ) )
    {
    	lua_newtable( L );
        lua_pushcfunction( L, vlclua_airplay_bonjour_delete );
        lua_setfield( L, -2, "__gc" );
    }
    
    lua_setmetatable( L, -2 );
    return 1;
}

static int vlclua_airplay_bonjour_delete( lua_State *L )
{
	AirplayAnnouncer **pp_announcer = (AirplayAnnouncer **)luaL_checkudata( L, 1, "airplay_bonjour_announcer" );
	[*pp_announcer stop];
	[*pp_announcer release];
	return 0;
}

/*****************************************************************************
 *
 *****************************************************************************/
void luaopen_airplay_bonjour( lua_State *L )
{
    lua_pushcfunction( L, vlclua_airplay_bonjour_register );
    lua_setfield( L, -2, "airplay_bonjour" );
}
