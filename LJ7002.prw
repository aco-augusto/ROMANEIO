#include 'protheus.ch'
#include 'parmtype.ch'

/*
------------------------------------------------------------------------------------------------------------
Fun��o		: LJ7002()
Tipo		: Ponto de Entrada
Descri��o	: Atualiza os valores de pre�o total, liquido e bruto do or�amento em quest�o
Chamado     : Ao concluir a grava��o do or�amento
Par�metros	:
Retorno		: 
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 27/11/2018 - Ronilson Rodrigues - Constru��o inicial do fonte
- 11/12/2018 - Ronilson Rodrigues - Inclus�o da altera��o para a filial 03, estava salvando os dados antigos
									do produto
------------------------------------------------------------------------------------------------------------
*/

User Function LJ7002()
	Local nVar 			:= ParamIxb[1]
	Local nPosQuant		:= aScan( aHeader, { |x| AllTrim( x[2] ) == "LR_QUANT"		} )
	Local nPosVlrUnit	:= aScan( aHeader, { |x| AllTrim( x[2] ) == "LR_VRUNIT"		} )
	Local nPosVlrTot	:= aScan( aHeader, { |x| AllTrim( x[2] ) == "LR_VLRITEM"	} )
	Local aValores		:= {}
	Local nVlrTot		:= 0
	Local nParcelas		:= 0
	Local nVlrParc		:= 0
	Local nValPTot		:= 0
	Local nDif			:= 0
	Local nX			:= 0
	Local nY			:= 0
	
	If cEmpAnt <> '00'
		Return
	EndIf
	
	// Se estiver alterando um or�amento, utilizando o usu�rio gerente e se usou a rotina
	If nVar == 1 .AND. ALTERA .AND. cUserName $ GetMV("XX_GERENTE") .AND. M->LQ_USOUTAB == 1
		// Recupera o valor total dos produtos
		For nX := 1 To Len(aCols)
			nVlrTot += aCols[nX, nPosVlrTot]
		Next nX
		
		// Abre a �rea da SL1 para atualizar o cabe�alho da venda
		DbSelectArea("SL1")
		SL2->(DbGoTop())
		DbSetOrder(1)
		
		If MsSeek(xFilial("SL1") + M->LQ_NUM)
			RecLock("SL1", .F.)
				SL1->L1_USOUTAB	:= 1
				SL1->L1_VLRTOT	:= nVlrTot
				SL1->L1_VLRLIQ	:= nVlrTot
				SL1->L1_VALBRUT	:= nVlrTot
				If aPgtosSint[1,1] == "R$"
					SL1->L1_DINHEIR := nVlrTot
					SL1->L1_ENTRADA := nVlrTot
				Else
					SL1->L1_FINANC := nVlrTot
				EndIf
			SL1->(MsUnlock())
		EndIf
		
		// Abre a �rea da SL2 para atualizar os produtos do or�amento
		DbSelectArea("SL2")
		SL2->(DbGoTop())
		DbSetOrder(1)
		
		If MsSeek(xFilial("SL2") + M->LQ_NUM)
			While SL2->L2_NUM == M->LQ_NUM
				RecLock("SL2", .F.)
					SL2->L2_BASEPS2 := SL2->L2_VLRITEM
					SL2->L2_BASECF2	:= SL2->L2_VLRITEM
				SL2->(MsUnlock())
				SL2->(dbSkip())
			EndDo
		EndIf
		
		// Recupera a quantidade de parcelas dessa venda e o valor principal da parcela
		nParcelas 	:= Posicione("SL1", 1, xFilial("SL1") +M->LQ_NUM, "L1_PARCELA")
		nVlrParc	:= Round(nVlrTot / nParcelas, 2)
		
		// Guarda as parcelas em um array, realizando uma soma das parcelas
		For nX := 1 To nParcelas
			aAdd(aValores, { nVlrParc })
			nValPTot += aValores[nX,1]
		Next nX
		
		// Se o valor dos produtos for diferente do valor da soma das parcelas, vai atualizar a �ltima parcela com a diferen�a entre elas
		If nVlrTot <> nValPTot
			nDif := nVlrTot - nValPTot
			aValores[nParcelas,1] += nDif
		EndIf
		
		// Abre a �rea da SL4 para atualizar as condi��es de pagamento
		DbSelectArea("SL4")
		SL2->(DbGoTop())
		DbSetOrder(1)
		
		If MsSeek(xFilial("SL4") + M->LQ_NUM)
			While SL4->L4_NUM == M->LQ_NUM
				nY += 1
				RecLock("SL4", .F.)
					SL4->L4_VALOR := aValores[nY,1]
				SL4->(MsUnlock())
				SL4->(dbSkip())
			EndDo
		EndIf
	EndIf
	
	If cFilAnt == "03"
		nY := 0
		// Abre a �rea da SL2 para atualizar os produtos do or�amento
		DbSelectArea("SL2")
		SL2->(DbGoTop())
		DbSetOrder(1)
		
		If MsSeek(xFilial("SL2") + M->LQ_NUM)
			While SL2->L2_NUM == M->LQ_NUM
				nY++
				RecLock("SL2", .F.)
					SL2->L2_QUANT	:= aCols[nY, nPosQuant]
					SL2->L2_VRUNIT	:= aCols[nY, nPosVlrUnit]
					SL2->L2_VLRITEM	:= aCols[nY, nPosVlrTot]
					SL2->L2_BASEPS2 := aCols[nY, nPosVlrTot]
					SL2->L2_BASECF2	:= aCols[nY, nPosVlrTot]
					SL2->L2_PRCTAB	:= aCols[nY, nPosVlrUnit]
				SL2->(MsUnlock())
				SL2->(dbSkip())
			EndDo
		EndIf
	EndIf

	IF ! Posicione("SL1", 1, xFilial("SL1") +M->LQ_NUM, "FOUND()")
		_cIO := "I"	
	ELSEIF ! Empty(SL1->L1_YROMAN)
		_cIO := "I"	
	ELSE
		_cIO := "A"	
	ENDIF

	//Inclui romaneio, quando for um or�amento
	IF nVar == 1
		if u_RomaneOk( SL1->L1_YROMAN, SL1->L1_YSEQROM ) $ "10,  "
			u_GRVROMAN(SL1->L1_DOC, SL1->L1_SERIE, SL1->L1_CLIENTE, 'SL1', _cIO, "10" ) 
		else
			Aviso("ATEN��O!", "N�o � permitido altear um romaneio, que j� mudou de fase.", { "Ok" })			
		endif
	ENDIF

	if nVar == 2
		IF u_RomaneOk( SL1->L1_YROMAN, SL1->L1_YSEQROM ) == "30"�
			u_GRVROMAN(SL1->L1_DOC, SL1->L1_SERIE, SL1->L1_CLIENTE, 'SL1', _cIO, "40" ) 
		ELSE
			Aviso("ATEN��O!", "Solicite a finaliza��o do romaneio, antes de realizar o faturamento.", { "Ok" })
		ENDIF
	endif

Return
/*

	//INCLUI ROMANEIO, QUANDO FOR UM OR�AMENTO 
	�IF�nVar == 1

		IF u_RomaneOk( SL1->L1_YROMAN, SL1->L1_YSEQROM ) == "10"�
			u_GRVROMAN(SL1->L1_DOC, SL1->L1_SERIE, SL1->L1_CLIENTE, 'SL1', _cIO, "10" ) 
		ELSE
			Aviso("ATEN��O!", "N�o � permitido altear um romaneio, que j� mudou de fase.", { "Ok" })
		ENDIF

����ENDIF

	//QUANDO FOR A VENDA - Finalizar Romaneio
	IF�nVar == 2 
		IF u_RomaneOk( SL1->L1_YROMAN, SL1->L1_YSEQROM ) == "30"�
			u_GRVROMAN(SL1->L1_DOC, SL1->L1_SERIE, SL1->L1_CLIENTE, 'SL1', _cIO, "40" ) 
		ELSE
			Aviso("ATEN��O!", "Solicite a finaliza��o do romaneio, antes de realizar o faturamento.", { "Ok" })
		ENDIF
����ENDIF

*/