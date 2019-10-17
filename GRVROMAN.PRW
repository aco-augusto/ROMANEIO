#include 'PROTHEUS.CH'
/*
------------------------------------------------------------------------------------------------------------
Função		: GRVROMAN()
Tipo		: Função
Descrição	: Responsável por gravar ou atualizar os dados do romaneio
Chamado     : 
Parâmetros	: NF-e ou Cupom; série do documento; fornecedor/cliente; qual a origem (SF1, SL1, SC5); qual
            operação (Inclusão, Alteração ou Deleção); qual fase está o romaneio
Retorno		:
------------------------------------------------------------------------------------------------------------
Atualizações:
- 10/10/2019 - Ronilson Rodrigues - Construção inicial do fonte
------------------------------------------------------------------------------------------------------------
*/

User Function GRVROMAN(cDoc, cSerie, cCliFor, cLoja, cOrigem, cOper, cFase)
    Local nI			:= 0
    Local nPosItem		:= 0
    Local nPosProd		:= 0
    Local nPosQtd		:= 0
    Default cSerie      := ""

    // Verifica qual origem está sendo para trazer a posição dos campos necessárias
    If AllTrim(cOrigem) == "SF1"
        nPosItem    := aScan(aHeader, {|x| AllTrim(x[2]) == "D1_ITEM"})
        nPosProd    := aScan(aHeader, {|x| AllTrim(x[2]) == "D1_COD"})
        nPosQtd     := aScan(aHeader, {|x| AllTrim(x[2]) == "D1_QUANT"})
    ElseIf AllTrim(cOrigem) == "SL1"
        nPosItem    := aScan(aHeader, {|x| AllTrim(x[2]) == "L2_ITEM"})
        nPosProd    := aScan(aHeader, {|x| AllTrim(x[2]) == "L2_PRODUTO"})
        nPosQtd     := aScan(aHeader, {|x| AllTrim(x[2]) == "L2_QUANT"})
    ElseIf AllTrim(cOrigem) == "SC5"
        nPosItem    := aScan(aHeader, {|x| AllTrim(x[2]) == "C6_ITEM"})
        nPosProd    := aScan(aHeader, {|x| AllTrim(x[2]) == "C6_PRODUTO"})
        nPosQtd     := aScan(aHeader, {|x| AllTrim(x[2]) == "C6_QTDVEN"})
    EndIf

    // Se for INCLUIR
    If AllTrim(cOper) == "I"
        // Grava o cabeçalho do romaneio
        RecLock("ZZ1", .T.)
        ZZ1->ZZ1_FILIAL := cFilAnt
        ZZ1->ZZ1_ROMAN	:= GetSxEnum("ZZ1", "ZZ1_ROMAN")
        ZZ1->ZZ1_SEQROM	:= u_PROXSEQ(ZZ1->ZZ1_ROMAN)
        ZZ1->ZZ1_DTINC	:= DDATABASE
        ZZ1->ZZ1_HRINC	:= Substr(TIME(), 1, 2) + Substr(TIME(), 4, 2)
        ZZ1->ZZ1_CODSOL	:= __cUserID
        ZZ1->ZZ1_FASE	:= cFase
        ZZ1->ZZ1_ES		:= If (AllTrim(cOrigem) == "SF1", 'E', 'S')
        ZZ1->ZZ1_ORIGEM	:= cOrigem
        ZZ1->ZZ1_DOCORI	:= cDoc
        ZZ1->ZZ1_SERORI	:= cSerie
        ZZ1->ZZ1_CLIFOR	:= cCliFor
        ZZ1->ZZ1_LOJA   := cLoja
        ZZ1->(MsUnlock())

        // Grava os itens do romaneio
        For nI := 1 To Len(aCols)
            RecLock("ZZ2", .T.)
            ZZ2->ZZ2_FILIAL := cFilAnt
            ZZ2->ZZ2_ROMAN	:= ZZ1->ZZ1_ROMAN
            ZZ2->ZZ2_SEQROM	:= ZZ1->ZZ1_SEQROM
            ZZ2->ZZ2_ITORI	:= aCols[nI, nPosItem]
            ZZ2->ZZ2_PROD	:= aCols[nI, nPosProd]
            ZZ2->ZZ2_QTDORI	:= aCols[nI, nPosQtd]
            ZZ2->(MsUnlock())
        Next nI

        // Grava o código do romaneio e a sequência no cabeçalho de origem
        If AllTrim(cOrigem) == "SF1"
            RecLock("SF1", .F.)
            SF1->F1_YROMAN	:= ZZ1->ZZ1_ROMAN
            SF1->F1_YSEQROM	:= ZZ1->ZZ1_SEQROM
            SF1->(MsUnlock())
        ElseIf AllTrim(cOrigem) == "SL1"
            RecLock("SL1", .F.)
            SL1->L1_YROMAN  := ZZ1->ZZ1_ROMAN
            SL1->L1_YSEQROM := ZZ1->ZZ1_SEQROM
            SL1->(MsUnlock())
        ElseIf AllTrim(cOrigem) == "SC5"
            RecLock("SC5", .F.)
            SC5->C5_YROMAN  := ZZ1->ZZ1_ROMAN
            SC5->C5_YSEQROM := ZZ1->ZZ1_SEQROM
            SC5->(MsUnlock())
        EndIf
    // Se for ALTERAR
    ElseIf AllTrim(cOper) == "A"
        dbSelectArea("ZZ1")
        ZZ1->(dbSetOrder(2))
        If ZZ1->(dbSeek(xFilial("ZZ1") + cOrigem + PADR(cDoc, TamSX3("ZZ1_DOCORI")[1]) + PADR(cSerie, TamSX3("ZZ1_SERORI")[1]) + cCliFor + cLoja))
            // Atualiza o cabeçalho do romaneio
            RecLock("ZZ1", .F.)
            ZZ1->ZZ1_DTINC  := DDATABASE
            ZZ1->ZZ1_HRINC  := Substr(TIME(), 1, 2) + Substr(TIME(), 4, 2)
            ZZ1->ZZ1_FASE   := cFase
            ZZ1->ZZ1_CLIFOR	:= cCliFor
            ZZ1->ZZ1_LOJA   := cLoja
            ZZ1->(MsUnlock())
        EndIf

        dbSelectArea("ZZ2")
        ZZ2->(dbSetOrder(1))
        // Atualiza os itens do romaneio
        For nI := 1 To Len(aCols)
            If ZZ2->(dbSeek(xFilial("ZZ2") + ZZ1->ZZ1_ROMAN + ZZ1->ZZ1_SEQROM + PADR(aCols[nI,nPosItem], TamSX3("ZZ2_ITORI")[1])))
                RecLock("ZZ2", .F.)
                If aCols[nI, Len(aHeader) + 1]
                    ZZ2->(DbDelete())
                Else
                    ZZ2->ZZ2_ITORI	:= aCols[nI, nPosItem]
                    ZZ2->ZZ2_PROD	:= aCols[nI, nPosProd]
                    ZZ2->ZZ2_QTDORI	:= aCols[nI, nPosQtd]
                EndIf
                ZZ2->(MsUnlock())
            EndIf
        Next nI
    // Se for DELETAR
    ElseIf AllTrim(cOper) == "D"
        dbSelectArea("ZZ1")
        ZZ1->(dbSetOrder(2))
        If ZZ1->(dbSeek(xFilial("ZZ1") + cOrigem + PADR(cDoc, TamSX3("ZZ1_DOCORI")[1]) + PADR(cSerie, TamSX3("ZZ1_SERORI")[1]) + cCliFor + cLoja))
            // Deleta o cabeçalho do romaneio
            RecLock("ZZ1", .F.)
            ZZ1->(DbDelete())
            ZZ1->(MsUnlock())
        EndIf

        dbSelectArea("ZZ2")
        ZZ1->(dbSetOrder(1))
        For nI := 1 To Len(aCols)
            If ZZ2->(dbSeek(xFilial("ZZ2") + ZZ1->ZZ1_ROMAN + ZZ1->ZZ1_SEQROM + PADR(aCols[nI,nPosItem], TamSX3("ZZ2_ITORI")[1])))
                // Deleta os itens do romaneio
                RecLock("ZZ2", .F.)
                ZZ2->(DbDelete())
                ZZ2->(MsUnlock())
            EndIf
        Next nI
    EndIf
Return