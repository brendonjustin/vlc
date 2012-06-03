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

#include <string.h>
#include <dns_sd.h>
#include <arpa/inet.h>


/*****************************************************************************
 * Structures
 *****************************************************************************/
typedef struct bonjour_t
{
    lua_State           *L;

    char                *psz_stype;
    char                *psz_name;
    char                *psz_domain;
    uint16_t            i_port;
    DNSServiceRef       *p_sdRef;
    TXTRecordRef        *p_txtRecord;
} bonjour_t;

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
    bonjour_t *p_sys = (bonjour_t *)calloc( 1, sizeof( bonjour_t ) );
    bonjour_t **pp_sys = lua_newuserdata( L, sizeof( bonjour_t *) );
    *pp_sys = p_sys;
    p_sys->L = L;

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
    int port;

    const char *psz_domain = luaL_checkstring( L, 2 );
    const char *psz_type = luaL_checkstring( L, 3 );
    const char *psz_hostname = luaL_checkstring( L, 4 );
    const char *psz_port = luaL_checkstring( L, 5 );
    port = atoi( psz_port );
    
    bonjour_t **pp_sys = (bonjour_t **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    bonjour_t *p_sys = *pp_sys;

    p_sys->psz_domain = strdup( psz_domain );
    p_sys->psz_name = strdup( psz_hostname );
    p_sys->psz_stype = strdup( psz_type );
    p_sys->i_port = port;

    p_sys->p_sdRef = malloc( sizeof(DNSServiceRef) );
    p_sys->p_txtRecord = malloc( sizeof(TXTRecordRef) );
    TXTRecordCreate( p_sys->p_txtRecord, 0, NULL );

    return 1;
}

static int vlclua_bonjour_delete( lua_State *L )
{
    bonjour_t **pp_sys = (bonjour_t **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    bonjour_t *p_sys = *pp_sys;

    // if( p_sys->psz_domain )
    //     free( p_sys->psz_domain );
    // if( p_sys->psz_name )
    //     free( p_sys->psz_name );
    // if( p_sys->psz_stype )
    //     free( p_sys->psz_stype );

    // if( p_sys->p_sdRef ) {
    //     DNSServiceRefDeallocate( *(p_sys->p_sdRef) );
    //     free( p_sys->p_sdRef );
    // }
    // if( p_sys->p_txtRecord ) {
    //     TXTRecordDeallocate( p_sys->p_txtRecord );
    //     free( p_sys->p_txtRecord );
    // }

    // free( p_sys );

    return 0;
}

static int vlclua_bonjour_add_record( lua_State *L )
{
    bonjour_t **pp_sys = (bonjour_t **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    bonjour_t *p_sys = *pp_sys;
    const char *psz_key = luaL_checkstring( L, 2 );
    const char *psz_value = luaL_checkstring( L, 3 );

    TXTRecordSetValue ( p_sys->p_txtRecord,
                        psz_key,
                        (uint8_t)strlen( psz_value ),
                        psz_value );

    return 1;
}

static int vlclua_bonjour_publish_service( lua_State *L )
{
    bonjour_t **pp_sys = (bonjour_t **)luaL_checkudata( L, 1, "bonjour_advertiser" );
    bonjour_t *p_sys = *pp_sys;

    DNSServiceRegister ( p_sys->p_sdRef,
                        0,
                        0,
                        p_sys->psz_name,
                        p_sys->psz_stype,
                        p_sys->psz_domain,
                        NULL,
                        htons( p_sys->i_port ),
                        TXTRecordGetLength( p_sys->p_txtRecord ),
                        TXTRecordGetBytesPtr( p_sys->p_txtRecord ),
                        NULL,
                        NULL );

    free( p_sys );

    return 0;
}

/*****************************************************************************
 *
 *****************************************************************************/
void luaopen_bonjour( lua_State *L )
{
    lua_pushcfunction( L, vlclua_bonjour_init );
    lua_setfield( L, -2, "bonjour" );
}
