local NPC_ID = 60001 --> Coloca aquí el ID del NPC que correrá este Script.
local verde, rojo, claro_rojo = "|cff00ff00", "|cffff0000", "|cffff5252"


local function ENVIAR_MENSAJE_BROADCAST(objeto, texto)
    objeto:SendBroadcastMessage(texto)
end


local function OBTENER_PORCENTAJE(Contestador, Ganados, Totales)
    if Totales > 0 then
        local porcentaje = (Ganados / Totales) * 100
        local color = ""

        if porcentaje < 40 then
            color = "|cffff0000" -- Rojo
        elseif porcentaje >= 41 and porcentaje <= 59 then
            color = "|cffffa500" -- Naranja
        elseif porcentaje >= 60 then
            color = "|cff00ff00" -- Verde
        end

        return string.format("Frente a frente con %s: %s%.2f|r", Contestador, color, porcentaje)
    else
        return string.format("Frente a frente con %s: |cffff00000.00|r", Contestador)
    end
end


local function AL_SOLICITAR_DUELO(e, objetivo, P)
    local jugador_id, objetivo_id = P:GetGUIDLow(), objetivo:GetGUIDLow()
    local nombre_jugador, nombre_objetivo = P:GetName(), objetivo:GetName()
    local nombre_jugador_min, nombre_objetivo_min = string.lower(P:GetName()), string.lower(objetivo:GetName())

    local consulta = CharDBQuery("SELECT `total` FROM `aa_duelos` WHERE `p_guid` = " .. jugador_id .. " AND `c_guid` = " .. objetivo_id .. "")

    local consulta_insercion = "INSERT IGNORE INTO `aa_duelos` (`p_guid`,`nombre`,`w`,`l`,`c_nombre`,`c_guid`,`total`) VALUES (%d,'%s',0,0,'%s',%d,0)"

    if not consulta then
        local consulta_jugador = string.format(consulta_insercion, jugador_id, nombre_jugador_min, nombre_objetivo_min, objetivo_id)
        local consulta_objetivo = string.format(consulta_insercion, objetivo_id, nombre_objetivo_min, nombre_jugador_min, jugador_id)
        CharDBExecute(consulta_jugador)
        CharDBExecute(consulta_objetivo)
    end

    local consulta_duelos = "SELECT `w`,`l`,`total` FROM `aa_duelos` WHERE `p_guid` = %d AND `c_guid` = %d"
    local consulta_duelos_formateada = string.format(consulta_duelos, jugador_id, objetivo_id)

    local function TEMPORIZADOR_1(ev, d, r, jugador_temp)
        local consulta_resultado = CharDBQuery(consulta_duelos_formateada)
        local ganados, perdidos, totales = consulta_resultado:GetUInt16(0), consulta_resultado:GetUInt16(1), consulta_resultado:GetUInt16(2)
        local versus1 = string.format("%s|r vs. %s|r:  %s|r - %s|r  Duelos totales: %d", nombre_jugador, nombre_objetivo, verde .. ganados, rojo .. perdidos, totales)
        ENVIAR_MENSAJE_BROADCAST(jugador_temp, versus1)
        ENVIAR_MENSAJE_BROADCAST(jugador_temp, OBTENER_PORCENTAJE(nombre_objetivo, ganados, totales) .. " %")
    end

    local function TEMPORIZADOR_2(ev, d, r, objetivo_temp)
        local consulta_resultado = CharDBQuery(consulta_duelos_formateada)
        local ganados, perdidos, totales = consulta_resultado:GetInt32(0), consulta_resultado:GetInt32(1), consulta_resultado:GetInt32(2)
        local versus2 = string.format("%s|r vs. %s|r:  %s|r - %s|r  Duelos totales: %d", nombre_objetivo, nombre_jugador, verde .. perdidos, rojo .. ganados, totales)
        ENVIAR_MENSAJE_BROADCAST(objetivo_temp, versus2)
        ENVIAR_MENSAJE_BROADCAST(objetivo_temp, OBTENER_PORCENTAJE(nombre_jugador, perdidos, totales) .. " %")
    end

    P:RegisterEvent(TEMPORIZADOR_1, 100, 1)
    objetivo:RegisterEvent(TEMPORIZADOR_2, 100, 1)
end


local function AL_TERMINAR_DUELO(e, ganador, perdedor, tipo)
    --[[ Tipos de duelo .. parámetro 'tipo'
    0 = Duelo cancelado. Porque se esperó demasiado para aceptar / se clickeó rechazar / forfeit antes de aceptar.
    1 = Duelo válido. Ha habido un ganador y un perdedor / alguien ha escrito forfeit en combate.
    2 = Alguien ha huído y el duelo se interrumpió.
    ]]

    local nombre_ganador, nombre_perdedor = string.lower(ganador:GetName()), string.lower(perdedor:GetName())

    local consulta_resultado_duelo = string.format("SELECT `w`,`l`,`total` FROM `aa_duelos` WHERE `nombre` = '%s' AND `c_nombre` = '%s'", nombre_ganador, nombre_perdedor)

    local resultado_duelo = CharDBQuery(consulta_resultado_duelo)
    local ganados, perdidos, totales = resultado_duelo:GetInt32(0), resultado_duelo:GetInt32(1), resultado_duelo:GetInt32(2)

    if (tipo == 0) or (tipo == 2) then
        local mensaje_cancelado, mensaje_huida = "Duelo cancelado, no se registró el resultado.", "Duelo inválido por huida, no se registró el resultado."
        if tipo == 0 then
            ENVIAR_MENSAJE_BROADCAST(ganador, claro_rojo .. mensaje_cancelado)
            ENVIAR_MENSAJE_BROADCAST(perdedor, claro_rojo .. mensaje_cancelado)
        elseif tipo == 2 then
            ENVIAR_MENSAJE_BROADCAST(ganador, claro_rojo .. mensaje_huida)
            ENVIAR_MENSAJE_BROADCAST(perdedor, claro_rojo .. mensaje_huida)
        end
        return
    end

    if tipo == 1 then
        local nombre_ganador_completo, nombre_perdedor_completo = ganador:GetName(), perdedor:GetName()
        CharDBExecute("UPDATE `aa_duelos` SET `w`=`w`+1, `total`=`total`+1 WHERE `nombre` = '" .. nombre_ganador_completo .. "'")
        CharDBExecute("UPDATE `aa_duelos` SET `l`=`l`+1, `total`=`total`+1 WHERE `nombre` = '" .. nombre_perdedor_completo .. "'")
        ganador:SendBroadcastMessage(nombre_ganador_completo .. "|r vs. " .. nombre_perdedor_completo .. "|r:  " .. verde .. (ganados + 1) .. "|r - " .. rojo .. perdidos .. "|r  Duelos totales: " .. (totales + 1))
        perdedor:SendBroadcastMessage(nombre_perdedor_completo .. "|r vs. " .. nombre_ganador_completo .. "|r:  " .. verde .. perdidos .. "|r - " .. rojo .. (ganados + 1) .. "|r  Duelos totales: " .. (totales + 1))
    end
end


local function AL_RECARGAR_SCRITPS(e)
    CharDBExecute("CREATE TABLE IF NOT EXISTS `aa_duelos` ("
        .. "`p_guid` MEDIUMINT UNSIGNED NOT NULL,"
        .. "`nombre` VARCHAR(18) NOT NULL,"
        .. "`w` MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,"
        .. "`l` MEDIUMINT UNSIGNED NOT NULL DEFAULT 0,"
        .. "`c_nombre` VARCHAR(18) NOT NULL,"
        .. "`c_guid` MEDIUMINT UNSIGNED NOT NULL,"
        .. "`total` MEDIUMINT UNSIGNED NOT NULL DEFAULT 0)")
end


local function MOSTRAR_SALUDO(e, P, npc)
    P:GossipClearMenu()
    P:GossipMenuAddItem(0, 'Consultar registros de duelos', 10, 1, true, 'Ingresa el nombre de la persona con la que tienes duelos registrados.')
    P:GossipSendMenu(1, npc, MenuId)
end


local function PROCESAR_CLICK(e, P, npc, seleccion, item, texto)
    local texto_min = string.lower(texto)

    if (seleccion == 10) and (item == 1) then
        local nombre_P = string.lower(P:GetName())
        local consulta_duelo = CharDBQuery("SELECT `w`,`l`,`total` FROM `aa_duelos` WHERE `nombre` = '" .. nombre_P .. "' AND `c_nombre` = '" .. texto_min .. "'")

        if not consulta_duelo then
            P:SendBroadcastMessage("No se encontró un historial de duelos con " .. texto)
            P:GossipComplete()
            return false
        end

        local ganados, perdidos, totales = consulta_duelo:GetInt32(0), consulta_duelo:GetInt32(1),
            consulta_duelo:GetInt32(2)
        P:SendBroadcastMessage(string.format("Duelos contra %s: %s - %s   Duelos totales: %d", texto, verde .. ganados, rojo .. perdidos, totales))
        P:SendBroadcastMessage(OBTENER_PORCENTAJE(texto, ganados, totales) .. " %")
        P:GossipComplete()
    end
end

RegisterPlayerEvent(11, AL_TERMINAR_DUELO)
RegisterPlayerEvent(9, AL_SOLICITAR_DUELO)
RegisterServerEvent(33, AL_RECARGAR_SCRITPS)
RegisterCreatureGossipEvent(NPC_ID, 1, MOSTRAR_SALUDO)
RegisterCreatureGossipEvent(NPC_ID, 2, PROCESAR_CLICK)
