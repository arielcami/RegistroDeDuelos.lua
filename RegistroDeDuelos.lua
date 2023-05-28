
local NPC = 00000  --> Coloca aquí el ID del NPC que correrá este Script.
local v,r,c = "|cff00ff00", "|cffff0000", "|cffff5252"

local function bc(ob,txt) ob:SendBroadcastMessage(txt) end

local function Al_Solicitar_Duelo(e, objetivo, jugador)----------------------------------------------------------------------------------------------------

    local guid1, guid2 = jugador:GetGUIDLow(), objetivo:GetGUIDLow()
    local Name1, Name2 = jugador:GetName(), objetivo:GetName()
    local name1, name2 = string.lower( jugador:GetName() ), string.lower( objetivo:GetName() )   

    local Q = CharDBQuery("SELECT `totalDuelos` FROM `aa_registroduelos` WHERE `p_guid` = "..guid1.." AND `c_guid` = "..guid2.."")
    local Qstr = "INSERT IGNORE INTO `aa_registroduelos` (`p_guid`,`nombre`,`ganados`,`perdidos`,`c_nombre`,`c_guid`,`totalDuelos`) VALUES (%d, '%s', 0, 0, '%s', %d, 0)"

    if not Q then 
        local Qstr_1 = string.format(Qstr, guid1, name1, name2, guid2)
        local Qstr_2 = string.format(Qstr, guid2, name2, name1, guid1)
        CharDBExecute(Qstr_1) 
        CharDBExecute(Qstr_2)
    end   

    local Q1 = "SELECT `ganados`,`perdidos`,`totalDuelos` FROM `aa_registroduelos` WHERE `p_guid` = %d AND `c_guid` = %d"
    local Q1str = string.format(Q1, guid1, guid2)
    
    local function Timed1(ev, del, rep, p1)
        local Q2 = CharDBQuery(Q1str)
        local gan,per,tot = Q2:GetInt32(0), Q2:GetInt32(1), Q2:GetInt32(2)
        local versus1 = string.format("%s|r vs. %s|r:  %s|r - %s|r  Duelos totales: %d", Name1, Name2, v..gan, r..per, tot)      
        bc(p1, versus1)  
    end
    local function Timed2(ev, del, rep, p2)
        local Q3 = CharDBQuery(Q1str)
        local gan,per,tot = Q3:GetInt32(0), Q3:GetInt32(1), Q3:GetInt32(2)
        local versus2 = string.format("%s|r vs. %s|r:  %s|r - %s|r  Duelos totales: %d", Name2, Name1, r..per, v..gan, tot)
        bc(p2, versus2)      
    end
    jugador:RegisterEvent(Timed1, 150, 1) 
    objetivo:RegisterEvent(Timed2, 150, 1)        

end--------------------------------------------------------------------------------------------------------------------------------------------------------

local function Al_Terminar_Duelo(e, ganador, perdedor, tipo) -----------------------------------------------------------------------------------------
--[[ 
    Tipos de duelo .. variable 'tipo'
    0 = Duelo cancelado. Porque se esperó demasiado para aceptar / se clickeó rechazar / forfeit antes de aceptar.
    1 = Duelo válido. Ha habido un ganador y un perdedor / alguien ha escrito forfeit en combate.
    2 = Alguien ha huído y el duelo se interrumpió.
]]
    local name1, name2 = string.lower(ganador:GetName()), string.lower(perdedor:GetName())
    local Q2str = string.format("SELECT `ganados`,`perdidos`,`totalDuelos` FROM `aa_registroduelos` WHERE `nombre` = '%s' AND `c_nombre` = '%s'", name1, name2)
    local Q2 = CharDBQuery(Q2str)
    local Gan,Per,Tot = Q2:GetInt32(0), Q2:GetInt32(1), Q2:GetInt32(2)
    
    if tipo==0 or tipo==2 then
        local str1, str2 = "Duelo cancelado, no se registró el resultado.", "Duelo inválido por huida, no se registró el resultado."
        if tipo == 0 then
            bc(ganador, c..str1)
            bc(perdedor, c..str1)
        elseif tipo == 2 then
            bc(ganador, c..str2)
            bc(perdedor, c..str2)
        end
        return
    end

    if tipo == 1 then 
        local Name1, Name2 = ganador:GetName(), perdedor:GetName()
        CharDBExecute("UPDATE `aa_registroduelos` SET `ganados`=`ganados`+1, `totalDuelos`=`totalDuelos`+1 WHERE `nombre` = '"..Name1.."'")
        CharDBExecute("UPDATE `aa_registroduelos` SET `perdidos`=`perdidos`+1, `totalDuelos`=`totalDuelos`+1 WHERE `nombre` = '"..Name2.."'")
        ganador:SendBroadcastMessage(Name1.."|r vs. "..Name2.."|r:  "..v..(Gan+1).."|r - "..r..Per.."|r  Duelos totales: "..(Tot+1))
        perdedor:SendBroadcastMessage(Name2.."|r vs. "..Name1.."|r:  "..v..Per.."|r - "..r..(Gan+1).."|r  Duelos totales: "..(Tot+1))   
    end
end -------------------------------------------------------------------------------------------------------------------------------------------------------

local function Eluna_Reload (e)--------------------------------------
    CharDBExecute("CREATE TABLE IF NOT EXISTS `aa_registroDuelos` ("
        .."`p_guid`         INT(10) NOT NULL,"
        .."`nombre`         VARCHAR(10) NOT NULL,"
        .."`ganados`        INT(10) NOT NULL DEFAULT 0,"
        .."`perdidos`       INT(10) NOT NULL DEFAULT 0,"
        .."`c_nombre`       VARCHAR(10) NOT NULL,"
        .."`c_guid`         INT(10) NOT NULL,"
        .."`totalDuelos`    INT(10) NOT NULL DEFAULT 0)")    
end------------------------------------------------------------------

local function Saludo (E,P,U) -------------------------------------------------------------------------------------------------------------------
    P:GossipClearMenu()
	P:GossipMenuAddItem(8, 'Consultar registros de duelos', 10, 1, true, 'Ingresa el nombre de la persona con la que tienes duelos registrados.')
	--P:GossipMenuAddItem(3, 'Quiero otros encantamientos...', 200, 200)
	P:GossipSendMenu(1, U, MenuId)
end ---------------------------------------------------------------------------------------------------------------------------------------------

local function Click (E,P,U,S,I,ST)         local str = string.lower(ST) -------------------------------------------------------------------------------------

    if S==10 and I==1 then

        local na1 = string.lower( P:GetName() )
        local qu = CharDBQuery("SELECT `ganados`,`perdidos`,`totalDuelos` FROM `aa_registroduelos` WHERE `nombre` = '"..na1.."' AND `c_nombre` = '"..str.."'")
        
        function up(st) return (st:gsub("^%l", string.upper)) end
        local N2 = up(str)
        
        if qu then
            local Gan,Per,Tot = qu:GetInt32(0), qu:GetInt32(1), qu:GetInt32(2)
            P:SendBroadcastMessage(P:GetName().."|r vs. "..N2.."|r:  "..v..Gan.."|r - "..r..Per.."|r  Duelos totales: "..Tot)
            P:GossipComplete()
        else
            P:SendBroadcastMessage("No se encontraron registros de duelos contra "..v..ST.."|r.")
            Saludo (E,P,U)
        end        
    end
end ----------------------------------------------------------------------------------------------------------------------------------------------------------

RegisterPlayerEvent(11, Al_Terminar_Duelo)  RegisterPlayerEvent(9, Al_Solicitar_Duelo)  RegisterServerEvent(33, Eluna_Reload)
RegisterCreatureGossipEvent(NPC, 1, Saludo)  RegisterCreatureGossipEvent(NPC, 2, Click)
