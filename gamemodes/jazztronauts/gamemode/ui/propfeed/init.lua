
util.AddNetworkString("propcollect")
util.AddNetworkString("brushcollect")
util.AddNetworkString("entitycollect")

AddCSLuaFile( "cl_init.lua")

module( "propfeed", package.seeall )

function notify( prop, ply, total, worth )

	net.Start( "propcollect" )
	net.WriteString( prop:GetModel() )
	net.WriteUInt( prop:GetSkin(), 16 )
	net.WriteUInt( total or 1, 16 )
	net.WriteUInt( worth or 0, 32 )
	net.WriteEntity( ply )
	net.Send( player.GetAll() )
end

function notify_brush( material, ply, worth )

	net.Start( "brushcollect" )
	net.WriteString( material )
	net.WriteUInt( worth or 0, 32 )
	net.WriteEntity( ply )
	net.Send( player.GetAll() )
end

function notify_entity( material, ply, worth )

	net.Start( "entitycollect" )
	net.WriteString( material )
	net.WriteUInt( worth or 0, 32 )
	net.WriteEntity( ply )
	net.Send( player.GetAll() )
end