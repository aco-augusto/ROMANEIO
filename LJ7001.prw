#Include "protheus.ch"

/*
------------------------------------------------------------------------------------------------------------
Fun��o		: LJ7001()
Tipo		: Ponto de Entrada
Descri��o	: Realiza a an�lise de cr�dito do cliente
Chamado     : Antes de gravar a venda
Par�metros	: Array de 3 posicoes (1-orcamento, 2-venda, 3-pedido)
Retorno		: L�gico
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 17/01/2012 - Henrique - Constru��o inicial do fonte
- 02/08/2013 - Sandro - Ajuste para adequar ao cliente
- 09/04/2019 - Ronilson Rodrigues - Altera��o parcial do c�digo
------------------------------------------------------------------------------------------------------------
*/

User Function LJ7001()
	Local nVar 			:= ParamIxb[1]
	Local lRet			:= .T.
	Local cAliasTmp
	Local cUsua			:= PswName()
	Local nSalCli 		:= 0
	Local nLimCred		:= 0
	Local aTipoTit  	:= StrToArray(AllTrim(SuperGetMv("MV_CRDTPLC")), ",")
	Local cFORMCRD 		:= SuperGetMv("MV_FORMCRD")
	Local nNumDias  	:= SuperGetMv("XX_DIASBLQ", .T., 60)
	Local nDiasSenha	:= SuperGetMv("XX_DIASSEN", .T., 5)
	Local nMVLIMMAX 	:= SuperGetMv("MV_LIMMAX")	// Limite m�ximo em percentual concedido sobre o limite de cr�dito do cliente, maior que isso n�o libera venda nem por senha
	Local cYobsBlq 		:= Posicione("SA1",1,xFilial("SA1")+M->LQ_CLIENTE,"A1_YOBSBLQ")
	Local cYobsRes 		:= Posicione("SA1",1,xFilial("SA1")+M->LQ_CLIENTE,"A1_YOBSRES")
	Local cTipoTit		:= ""
	Local cVctMaisAnt 	:= ""
	Local lShowErro 	:= .F.
	Local cMsgStatus 	:= ""
	Local lPedeSenha 	:= .F.
	Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PRODUTO"})][2]// Posicao da codigo do produto
	Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_DESCRI"})][2]	// Posicao da Descricao do produto
	Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_QUANT"})][2]	// Posicao da Quantidade
	Local nPosDtReserva	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_RESERVA"})			// Posicao do codigo da reserva
	Local nPosDtLocal  	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOCAL"})			// Posicao do local (armazem)
	Local nPosTes		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_TES"})				// Posicao da TES
	Local nX 			:= 0																	// Variavel auxiliar
	Local cEstNeg		:= (SuperGetMv("MV_ESTNEG") == "S")										// Indica se permite ou nao estoque negativo
	Local cMsg			:= ""																	// Mensagem com o codigo e o produto
	Local aSldProdutos	:= {}																	// Array usada para validar o saldo de todos os produtos
	Local nPosSldProd	:= 0																	// Variavel auxiliar para busca do codigo do produto no array para considerar os saldos
	Local nQuantidade	:= 0
	Local cGrupoServ 	:= GETMV("XX_GRUPSERV",,"9999")
	Local lServico		:= .F.
	Local lProduto		:= .F.
	Local lBlocCred  	:= .F.
	Local cMsgTitulo    := ""
	Local lObsBlq		:= .F.
	Local lTitVencido   := .F.
	Local nTitAbertos   := 0
	Local nRiscoB		:= nNumDias * 2
	Local lAtraso		:= .F.
	Local lLim			:= .F.
	Local cTab			:= Posicione("SA1", 1, xFilial("SA1") + M->LQ_CLIENTE, "A1_TABELA")
	Local cGerentes		:= ""
	Local lObsRes		:= .F.
	Local nI			:= 0
	Static lSenhaVend	:= .F.
	Local cCGC			:= ""
	Local lPlaca		:= ""
	Local lMecanico		:= ""
	Local nQatu			:= 0
	Local nQNaoClas		:= 0
	Local nQPedVen		:= 0
	Local nSaldo		:= 0
	
	If cEmpAnt == "00"
		lPlaca		:= Posicione("SA1", 1, xFilial("SA1") + M->LQ_CLIENTE, "A1_YPLACA")
		lMecanico	:= Posicione("SA1", 1, xFilial("SA1") + M->LQ_CLIENTE, "A1_YMECANI")
		// Verifica se est� marcado no cadastro placa e/ou mec�nico e se foi preenchido na venda
		If (lPlaca .AND. Empty(M->LQ_YPLACA)) .OR. (lMecanico .AND. Empty(M->LQ_YMECANI))
			If Len(M->LQ_YPLACA) < 7 .OR. Len(M->LQ_YMECANI) < 3
				MsgStop("Texto dos campos Placa ou Mecanico insuficientes, favor colocar informa��o v�lida.")
			EndIf 
			If lPlaca .AND. !lMecanico
				MsgStop("Preencha o campo Placa no cabe�alho da venda, pois este cliente requisitou esta informa��o.")
			ElseIf !lPlaca .AND. lMecanico
				MsgStop("Preencha o campo Mecanico no cabe�alho da venda, pois este cliente requisitou esta informa��o.")
			Else
				MsgStop("Preencha os campos Placa e Mecanico no cabe�alho da venda, pois este cliente requisitou estas informa��es.")
			EndIf
			Return .F.
		EndIf
	EndIf
	
	// Verifica se foi utilizado tabela e desconto no or�amento ao mesmo tempo
	If (M->LQ_USOUTAB == 1 .OR. ! Empty(cTab)) .AND. (aDesconto[2] <> 0 .OR. aDesconto[3] <> 0)
		MsgStop("Foi utilizada a tabela de pre�o junto com desconto da rotina. Corrija essa situa��o.", "Aten��o!")
		Return .F.
	EndIf
	
	If cEmpAnt == '00'
		cGerentes	:= GetMV("XX_GERENTE")
		If Altera .AND. cUserName $ cGerentes
			Return .T.
		EndIf
	EndIf
	
	If !u_ValCondPag()
		Return .F.
	EndIF
	
	If nVar == 1
		If cEmpAnt == "00"
			For nX := 1 to Len(aCols)
				If !aCols[nX][Len(aCols[nX])]
	
					// Identifica se h� itens do grupo "SERVI�OS" junto com produtos de venda
					cGrupo := Posicione("SB1",1,xFilial("SB1")+aCols[nX][nPosProd],"B1_GRUPO")
					If Alltrim(cGrupo) $ cGrupoServ
						lServico := .T.
					Else
						lProduto := .T.
					EndIf
	
					// Somente verIfica o estoque caso nao tenha sido feita a reserva do produto
					If Empty(aColsDet[nX][nPosDtReserva])
						// Vai adicionando os produtos em um array para considerar a quantidade de
						// todas as linhas do mesmo produto. Considera sempre o produto + local para
						// a pesquisa no SB2
						nPosSldProd := aScan( aSldProdutos, { |x| x[1] == aCols[nX][nPosProd] + aColsDet[nX][nPosDtLocal] } )
						If nPosSldProd > 0
							nQuantidade := aCols[nX][nPosQuant] + aSldProdutos[ nPosSldProd ][ 2 ]
							aSldProdutos[ nPosSldProd ][ 2 ] := nQuantidade
						Else
							nQuantidade := aCols[nX][nPosQuant]
							aAdd( aSldProdutos, { aCols[nX][nPosProd] + aColsDet[nX][nPosDtLocal], nQuantidade } )
						EndIf
	
						// Devo passar a quantidade de cada item e nao o total do produto, pois, na
						// funcao Lj7VerEst ja estou varrendo o acols e totalizando  a quantidade do produto
						/* If !(Lj7VerEst( aCols[nX][nPosProd]	, aColsDet[nX][nPosDtLocal]	, aCols[nX][nPosQuant]	, .F.	,;
								nX					, aColsDet[nX][nPosTes] )) */
						nQatu		:= Posicione("SB2", 1, xFilial("SB2") + aCols[nX,nPosProd], "B2_QATU")
						nQNaoClas	:= Posicione("SB2", 1, xFilial("SB2") + aCols[nX,nPosProd], "B2_NAOCLAS")
						nQPedVen	:= Posicione("SB2", 1, xFilial("SB2") + aCols[nX,nPosProd], "B2_QPEDVEN")

						nSaldo		:= (nQatu + nQNaoClas) - (nQPedVen + aCols[nX, nPosQuant])
						If nSaldo < 0 .AND. !aCols[nX, Len(aHeader) + 1]
							cMsg += Alltrim(aCols[nX][nPosProd]) + " - " + Alltrim(aCols[nX][nPosDesc]) + Chr(10)
						EndIf
					EndIf
				EndIf
			Next nX
	
			If lServico .AND. lProduto
				lRet := .F.
				MsgStop('Or�amento n�o pode conter itens de "Servi�o" e "Produtos" simultaneamente.')
				Return lRet
			EndIf
	
			If  !cEstNeg .AND. !Empty(cMsg)
				lRet :=.F.
				MsgStop("N�o ser� permitido finalizar a venda pois os produtos abaixo n�o possuem saldo em estoque." + Chr(10) + cMsg)
				Return lRet
			EndIf
	
			// Fim da verifica��o de estoque negativo
	
			cRisco := Posicione("SA1",1,xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA,"A1_RISCO")
			If AllTrim(cRisco)=="A"
				Return .T.
			ElseIf AllTrim(cRisco)=="E"
				Alert("Este cliente tem Risco 'E', por isto a venda ser� bloqueada. Favor verificar com o setor respons�vel.")
				Return .F.
			ElseIf Empty(cRisco)
				Alert("Este cliente n�o tem Risco Definido. A venda ser� bloqueada. Favor verificar com o setor respons�vel.")
				Return .F.
			EndIf
			If AllTrim(cRisco) == "B"
				nNumDias := nRiscoB
			EndIf
			
			// Verifica se forma de pagamento atende para continuar rotina (INICIO)
			If !Empty(cFORMCRD)
				lAcheiCrdTip := .F.
				For nI := 1 to Len(aPgtos)	// Vetor aPgtos � do fonte padr�o Loja701b.prw
					If AllTrim(aPgtos[nI,3]) $ cFORMCRD
						lAcheiCrdTip := .T.
					EndIf
				Next
				If ! lAcheiCrdTip
					lRet := .T.
					Return lRet
				EndIf
			EndIf
			// Verifica se forma de pagamento atende para continuar rotina (FIM)
	
			// Verifica se tipo de t�tulo atende para continuar rotina (INICIO)
			cA1YCRDTIP := Posicione("SA1",1,xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA,"A1_YCRDTIP")
	
			If !Empty(cA1YCRDTIP)
				lAcheiCrdTip := .F.
				For nI := 1 to Len(aPgtos)	// Vetor aPgtos � do fonte padr�o Loja701b.prw
					If AllTrim(aPgtos[nI,3]) $ cA1YCRDTIP
						lAcheiCrdTip := .T.
					EndIf
				Next
				If !lAcheiCrdTip
					lRet := .F.
					Alert("Esta Forma de Pagamento n�o � permitida para este cliente.")
					Return lRet
				EndIf
			Else
				lRet := .F.
				Alert("Este cliente n�o tem Forma de Pagamento liberada definida. Favor verificar.")
				Return lRet
			EndIf
			// Verifica se tipo de t�tulo atende para continuar rotina (FIM)
	
			// Obt�m a data de vencimento mais antiga (INICIO)
			If Len(aTipoTit)>0
				cTipoTit	:= ""
				For nI := 1 to Len(aTipoTit)
					cTipoTit += aTipoTit[nI]
					If nI == Len(aTipoTit)
						cTipoTit += ""
					Else
						cTipoTit += "','"
					EndIf
				Next nI
			ElseIf Len(aTipoTit)==1
				cTipoTit := "'"+aTipoTit[1]+"'"
			EndIf
	
			cCGC := Posicione("SA1", 1, xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA, "A1_CGC")
			
			cAliasTmp := GetNextAlias()
			BeginSql Alias cAliasTmp
	
				SELECT ISNULL(MIN(E1_VENCREA),' ') VCTO
				FROM %Table:SE1% SE1
				INNER JOIN %Table:SA1% SA1
				ON SA1.A1_FILIAL = SE1.E1_FILIAL
				AND SA1.A1_COD = SE1.E1_CLIENTE
				AND SA1.A1_LOJA = SE1.E1_LOJA
				AND SA1.%NotDel%
				WHERE
				SE1.%NotDel%
				AND A1_CGC = %Exp:cCGC%
				AND E1_TIPO IN (%Exp:cTipoTit%)
				AND E1_STATUS = 'A'
				AND E1_SALDO > 0
			EndSql
			cVctMaisAnt := (cAliasTmp)->VCTO
	
			// SALDO (INICIO)
			cAliasTmp := GetNextAlias()
			BeginSql Alias cAliasTmp
	
				SELECT SUM(E1_SALDO) SALDO
				FROM %Table:SE1% SE1
				INNER JOIN %Table:SA1% SA1
				ON SA1.A1_FILIAL = SE1.E1_FILIAL
				AND SA1.A1_COD = SE1.E1_CLIENTE
				AND SA1.A1_LOJA = SE1.E1_LOJA
				AND SA1.%NotDel%
				WHERE
				SE1.%NotDel%
				AND A1_CGC = %Exp:cCGC%
				AND E1_TIPO IN (%Exp:cTipoTit%)
				AND E1_STATUS = 'A'
				AND E1_SALDO > 0
			EndSql
	
			nTitAbertos := (cAliasTmp)->SALDO
	
			(cAliasTmp)->(DbCloseArea())
			
			lObsRes	:= Iif(!Empty(AllTrim(cYobsRes)), .T., .F.)
			// Verifica os campos B1_YOBSBLQ + B1_YOBSRES est�o preenchidos
			if  (!Empty(alltrim(cYobsBlq)) .or. !Empty(alltrim(cYobsRes)))
				cMsgStatus += cYobsBlq + CRLF
				cMsgStatus += cYobsRes + CRLF
				cMsgStatus += "_________________________________________________" + CRLF
				lPedeSenha := .T.
				lObsBlq	   := .T.
				cMsgTitulo := "Bloqueio por Restri��o do Cliente"
			EndIf
	
			// An�lise de cr�dito por vencimento de t�tulos
			If nTitAbertos > 25
				If StoD(cVctMaisAnt) < dDataBase - nDiasSenha  .and. !Empty(cVctMaisAnt)
					If StoD(cVctMaisAnt) < dDataBase - nNumDias
						cMsgStatus 	+= "Cliente com titulo vencido h� mais de: "+Str(nNumDias,4,0) +" dias." + CRLF
						cMsgStatus  += "Titulo Vencido em "+DtoC(StoD(cVctMaisAnt)) + CRLF
						cMsgStatus  += "_____________________________________" + CRLF
						If lObsBlq
							cMsgTitulo := cMsgTitulo + " | Bloqueio por T�tulo em Atraso"
						Else
							cMsgTitulo  := "Bloqueio por T�tulo em Atraso"
						EndiF
						lPedeSenha 	:= .F.
						lTitVencido := .T.
					Else
						cMsgStatus 	+= "Cliente com titulo vencido h� mais de: " + Str(nDiasSenha,4,0) + " dias." + CRLF
						cMsgStatus  += "Titulo Vencido em "+DtoC(StoD(cVctMaisAnt)) + CRLF
						cMsgStatus  += "_____________________________________" + CRLF
						lTitVencido := .T.
						If lObsBlq
							cMsgTitulo 	:= cMsgTitulo + " | Bloqueio por T�tulo em Atraso"
						Else
							cMsgTitulo  := "Bloqueio por T�tulo em Atraso"
						EndiF
						If !lObsBlq
							lPedeSenha 	:= .T.
							lTitVencido := .T.
						EndIf
					EndIf
					lAtraso		:= .T.
				EndIf
			EndIf
	
			// Totaliza compra atual
			nPos:=aScan(aTotais,{|x| x[1] == "Total da Venda"})
			If nPos==0
				nPos:=aScan(aTotais,{|x| x[1] == "Total de Mercadorias"})
			EndIf
			nValorCompra := 0
			If nPos > 0
				nValorCompra := aTotais[nPos,2]
			EndIf
	
			DbSelectArea("SA1")
			DbSetOrder(1)
			If DbSeek(xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA)
				nSalCli  := 0
				nLimCred := 0
				nLimCred := SA1->A1_LC
			EndIf
	
			nPERLIMMAX := ((nLimCred * nMVLIMMAX) / 100)
	
			nSalCli := nTitAbertos + nValorCompra
			nLimMax := nLimCred + nPERLIMMAX
	
			// An�lise de limite de cr�dito
			// Verifica se a compra + saldo > Limite Cred + Toler�ncia, e menor que limite m�ximo, ent�o, pede senha
			If nSalCli > nLimCred
				If  nSalCli < nLimMax
					cMsgStatus += "Valor ultrapassou o Limite de Cr�dito de: " + TRANSFORM(nLimCred,"@E 999,999.99")+CRLF
					cMsgStatus += "Total da compra + t�tulos em aberto: "+ TRANSFORM(nSalCli,"@E 999,999.99")+ CRLF
					cMsgStatus += "_________________________________________________" + CRLF
					If lTitVencido .or. lObsBlq
						cMsgTitulo  := cMsgTitulo +  " e por Limite de Cr�dito"
					Else
						cMsgTitulo  := "Bloqueio por Limite de Cr�dito"
					EndIf
					If !lTitVencido
						lPedeSenha := .T.
					EndIf
					lBlocCred  := .T.
					lShowErro  := .T.
				ElseIf nSalCli > nLimMax
					cMsgStatus += "Valor ultrapassou o Limite M�ximo de: " + TRANSFORM(nLimCred,"@E 99,999.99")+ " + " + TRANSFORM(nMVLIMMAX,"@E 999") + "% = " + TRANSFORM(nLimMax,"@E 99,999.99") + CRLF
					cMsgStatus += "Total da compra + t�tulos em aberto: "+ TRANSFORM(nSalCli,"@E 999,999.99")+ CRLF
					cMsgStatus += "_______________________________________________________" + CRLF
					If lTitVencido .or. lObsBlq
						cMsgTitulo  := cMsgTitulo +  " e por Limite de Cr�dito"
					Else
						cMsgTitulo  := "Bloqueio por Limite de Cr�dito"
					EndIf
					lPedeSenha := .F.
					lBlocCred  := .T.
					lShowErro  := .T.
				EndIf
				lLim		:= .T.
			EndIf
			
			lSenhaVend	:= .F.
			//Mostra mensagem
			If !lPedeSenha .and. (lTitVencido .or. lBlocCred .or. lObsBlq)
				cMsgStatus += "Favor entrar em contato com o Financeiro."
				lRet := .F.
				MSGALERT(cMsgStatus,cMsgTitulo )
				Return lRet
			ElseIf lPedeSenha .and. (lTitVencido .or. lBlocCred .or. lObsBlq)
				If lObsRes .AND. Empty(alltrim(cYobsBlq)) .AND. !lTitVencido .AND. !lBlocCred
					cMsgStatus += "A senha do VENDEDOR ser� exigida." + CRLF
					lSenhaVend := .T.
				Else
					cMsgStatus += "A senha do GERENTE ser� exigida." + CRLF
				EndIf
				lPedeSenha := .T.
				MSGALERT(cMsgStatus,cMsgTitulo)
			EndIf
	
			// Exibe a tela de senha
			If lPedeSenha
				If FAT004(cMsgStatus)	// Se acertar senha, confirma gravacao
					lRet := .T.
					If AllTrim(cEmpAnt) <> "03"
						dbSelectarea("SZB")
						dbSetOrder(5)
						If .not. SZB->(dbSeek(xFilial("SZB")+M->LQ_NUM))
							RecLock("SZB",.T.)
						Else
							RecLock("SZB",.F.)
						EndIF
						SZB->ZB_FILORC	:= cFilAnt
						SZB->ZB_CLIENTE	:= M->LQ_CLIENTE
						SZB->ZB_LOJA	:= M->LQ_LOJA
						SZB->ZB_USUARIO	:= cCodUse
						SZB->ZB_ORCA	:= M->LQ_NUM
						SZB->ZB_LC		:= nLimCred
						SZB->ZB_SALDO	:= nSalCli
						SZB->ZB_DATA	:= M->LQ_EMISSAO
						SZB->ZB_MSG		:= cMsgStatus
						Do Case
						Case lAtraso .AND. !lLim		// Se for s� atraso
							SZB->ZB_MOTIVO	:= "Bloqueio por atraso"
						Case !lAtraso .AND. lLim		// Se for s� limite
							SZB->ZB_MOTIVO	:= "Bloqueio por limite de credito"
						Case lAtraso .AND. lLim			// Se for atraso e limite
							SZB->ZB_MOTIVO	:= "Bloqueio por atraso e limite de credito"
						EndCase
						SZB->(MsUnlock())
						SZB->(dbCloseArea())
					EndIf
				Else	// Se pressionar Cancela ou errar Senha, n�o grava
					lRet := .F.
				EndIf
			EndIf
		Else
			If u_ValCondPag() == .F.
				Return .F.
			EndIF
	
			For nX := 1 to Len(aCols)
				If !aCols[nX][Len(aCols[nX])]
	
					// IDENTIFICA SE H� ITENS DO GRUPO "SERVI�OS" JUNTO COM PRODUTOS DE VENDA
					cGrupo := Posicione("SB1",1,xFilial("SB1")+aCols[nX][nPosProd],"B1_GRUPO")
					If Alltrim(cGrupo) $ cGrupoServ
						lServico := .T.
					Else
						lProduto := .T.
					EndIf
	
					//���������������������������������������������������������������������������Ŀ
					//� Somente verIfica o estoque caso nao tenha sido feita a reserva do produto �
					//�����������������������������������������������������������������������������
					If Empty(aColsDet[nX][nPosDtReserva])
						//���������������������������������������������������������������������������Ŀ
						//� Vai adicionando os produtos em um array para considerar a quantidade de   �
						//� todas as linhas do mesmo produto. Considera sempre o produto + local para �
						//� a pesquisa no SB2                                                         �
						//�����������������������������������������������������������������������������
						nPosSldProd := aScan( aSldProdutos, { |x| x[1] == aCols[nX][nPosProd] + aColsDet[nX][nPosDtLocal] } )
						If nPosSldProd > 0
							nQuantidade := aCols[nX][nPosQuant] + aSldProdutos[ nPosSldProd ][ 2 ]
							aSldProdutos[ nPosSldProd ][ 2 ] := nQuantidade
						Else
							nQuantidade := aCols[nX][nPosQuant]
							aAdd( aSldProdutos, { aCols[nX][nPosProd] + aColsDet[nX][nPosDtLocal], nQuantidade } )
						EndIf
	
						//������������������������������������������������������������������������������������Ŀ
						//�Devo passar a quantidade de cada item e nao o total do produto, pois, na            �
						//�funcao Lj7VerEst ja estou varrendo o acols e totalizando  a quantidade do produto   �
						//��������������������������������������������������������������������������������������
						/* If !(Lj7VerEst( aCols[nX][nPosProd]	, aColsDet[nX][nPosDtLocal]	, aCols[nX][nPosQuant]	, .F.	,;
								nX					, aColsDet[nX][nPosTes] )) */
						nQatu		:= Posicione("SB2", 1, xFilial("SB2") + aCols[nX,nPosProd], "B2_QATU")
						nQNaoClas	:= Posicione("SB2", 1, xFilial("SB2") + aCols[nX,nPosProd], "B2_NAOCLAS")
						nQPedVen	:= Posicione("SB2", 1, xFilial("SB2") + aCols[nX,nPosProd], "B2_QPEDVEN")

						nSaldo		:= (nQatu + nQNaoClas) - (nQPedVen + aCols[nX, nPosQuant])
						If nSaldo < 0 .AND. !aCols[nX, Len(aHeader) + 1]
							cMsg := cMsg + Alltrim(aCols[nX][nPosProd]) + "-" + Alltrim(aCols[nX][nPosDesc]) + " | "
						EndIf
					EndIf
				EndIf
			Next nX
	
			If lServico .AND. lProduto
				lRet := .F.
				MsgStop('Or�amento n�o pode conter itens de "Servi�o" e "Produtos" simultaneamente.')
				Return lRet
			EndIf
	
			If  !cEstNeg .AND. !Empty(cMsg)
				lRet :=.F.
				MsgStop("N�o ser� permitido finalizar a venda pois os produtos abaixo n�o possuem saldo em estoque." + Chr(10) +;
					Subst(cMsg,1,Len(cMsg)-3) )
				Return lRet
			EndIf
	
			// FIM DA VERIFICA��O DE ESTOQUE NEGATIVO
	
		//	If nVar <> 1
		//		lRet := .F.
		//		MsgInfo("Nao � permitido Tipo Venda/Pedido, somente or�amento","Atencao","ALERT")
		//		Return lRet
		//	Endif
	
			cRisco := Posicione("SA1",1,xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA,"A1_RISCO")
			If AllTrim(cRisco)=="A"
				Return .T.
			ElseIf AllTrim(cRisco)=="E"
				Alert("Este cliente tem Risco 'E', por isto a venda ser� bloqueada. Favor verificar com o setor respons�vel.")
				Return .F.
			ElseIf Empty(cRisco)
				Alert("Este cliente n�o tem Risco Definido. A venda ser� bloqueada. Favor verificar com o setor respons�vel.")
				Return .F.
			EndIf
			If AllTrim(cRisco) == "B"
				nNumDias := nRiscoB
			EndIf
			// VERIFICA SE FORMA DE PAGAMENTO ATENDE PARA CONTINUAR ROTINA (INICIO)
	
			If !Empty(cFORMCRD)
				lAcheiCrdTip := .F.
				For nI := 1 to Len(aPgtos)	// Vetor aPgtos � do fonte padr�o Loja701b.prw
					If AllTrim(aPgtos[nI,3]) $ cFORMCRD
						lAcheiCrdTip := .T.
					EndIf
				Next
				If ! lAcheiCrdTip
					lRet := .T.
					Return lRet
				EndIf
			EndIf
	
			// VERIFICA SE FORMA DE PAGAMENTO ATENDE PARA CONTINUAR ROTINA (FIM)
	
			// VERIFICA SE TIPO DE TITULO ATENDE PARA CONTINUAR ROTINA (INICIO)
	
			cA1YCRDTIP := Posicione("SA1",1,xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA,"A1_YCRDTIP")
	
			If !Empty(cA1YCRDTIP)
				lAcheiCrdTip := .F.
				For nI := 1 to Len(aPgtos)	// Vetor aPgtos � do fonte padr�o Loja701b.prw
					If AllTrim(aPgtos[nI,3]) $ cA1YCRDTIP
						lAcheiCrdTip := .T.
					EndIf
				Next
				If !lAcheiCrdTip
					lRet := .F.
					Alert("Esta Forma de Pagamento n�o � permitida para este cliente.")
					Return lRet
				EndIf
			Else
				lRet := .F.
				Alert("Este cliente n�o tem Forma de Pagamento liberada definida. Favor verificar.")
				Return lRet
			EndIf
	
			// VERIFICA SE TIPO DE TITULO ATENDE PARA CONTINUAR ROTINA (FIM)
	
	
			// OBTEM A DATA DE VENCIMENTO MAIS ANTIGA (INICIO)
			If Len(aTipoTit)>0
				cTipoTit	:= ""
				For nI := 1 to Len(aTipoTit)
					cTipoTit += aTipoTit[nI]
					If nI == Len(aTipoTit)
						cTipoTit += ""
					Else
						cTipoTit += "','"
					EndIf
				Next nI
			ElseIf Len(aTipoTit)==1
				cTipoTit := "'"+aTipoTit[1]+"'"
			EndIf
	
			cAliasTmp := GetNextAlias()
			BeginSql Alias cAliasTmp
	
				SELECT ISNULL(MIN(E1_VENCREA),' ') VCTO
				FROM %Table:SE1% SE1
				WHERE
				SE1.%NotDel%
				AND E1_CLIENTE=%Exp:M->LQ_CLIENTE%
				AND E1_LOJA=%Exp:M->LQ_LOJA%
				AND E1_TIPO IN (%Exp:cTipoTit%)
				AND E1_STATUS='A'
				AND E1_SALDO > 0
			EndSql
			cVctMaisAnt := (cAliasTmp)->VCTO
	
			// SALDO (INICIO)
			cAliasTmp := GetNextAlias()
			BeginSql Alias cAliasTmp
	
				SELECT SUM(E1_SALDO) SALDO
				FROM  %Table:SE1% SE1
				WHERE
				SE1.%NotDel%
				AND E1_CLIENTE=%Exp:M->LQ_CLIENTE%
				AND E1_LOJA=%Exp:M->LQ_LOJA%
				AND E1_TIPO IN (%Exp:cTipoTit%)
				AND E1_STATUS='A'
				AND E1_SALDO > 0
			EndSql
	
			nTitAbertos := (cAliasTmp)->SALDO
	
			(cAliasTmp)->(DbCloseArea())
	
			// Verifica os campos b1_YobsBlq + b1_YobsRes Est�o preenchidos
			if  (!Empty(alltrim(cYobsBlq)) .or. !Empty(alltrim(cYobsRes)))
				cMsgStatus += cYobsBlq + CRLF
				cMsgStatus += cYobsRes + CRLF
				cMsgStatus += "_________________________________________________" + CRLF
				lPedeSenha := .T.
				lObsBlq	   := .T.
				cMsgTitulo := "Bloqueio por Restri��o do Cliente"
			EndIf
	
			//ANALISE DE CR�DITO POR VENCIMENTO DE T�TULOS
			If nTitAbertos > 25
				If StoD(cVctMaisAnt) < dDataBase - nDiasSenha  .and. !Empty(cVctMaisAnt)
					If StoD(cVctMaisAnt) < dDataBase - nNumDias
						cMsgStatus 	+= "Cliente com titulo vencido h� mais de: "+Str(nNumDias,4,0) +" dias." + CRLF
						cMsgStatus  += "Titulo Vencido em "+DtoC(StoD(cVctMaisAnt)) + CRLF
						cMsgStatus  += "_____________________________________" + CRLF
						If lObsBlq
							cMsgTitulo := cMsgTitulo + " | Bloqueio por T�tulo em Atraso"
						Else
							cMsgTitulo  := "Bloqueio por T�tulo em Atraso"
						EndiF
						lPedeSenha 	:= .F.
						lTitVencido := .T.
					Else
						cMsgStatus 	+= "Cliente com titulo vencido h� mais de: " + Str(nDiasSenha,4,0) + " dias." + CRLF
						cMsgStatus  += "Titulo Vencido em "+DtoC(StoD(cVctMaisAnt)) + CRLF
						cMsgStatus  += "_____________________________________" + CRLF
						lTitVencido := .T.
						If lObsBlq
							cMsgTitulo 	:= cMsgTitulo + " | Bloqueio por T�tulo em Atraso"
						Else
							cMsgTitulo  := "Bloqueio por T�tulo em Atraso"
						EndiF
						If !lObsBlq
							lPedeSenha 	:= .T.
							lTitVencido := .T.
						EndIf
					EndIf
					lAtraso		:= .T.
				EndIf
			EndIf
	
			// TOTALIZAR COMPRA ATUAL
			nPos:=aScan(aTotais,{|x| x[1] == "Total da Venda"})
			If nPos==0
				nPos:=aScan(aTotais,{|x| x[1] == "Total de Mercadorias"})
			EndIf
			nValorCompra := 0
			If nPos > 0
				nValorCompra := aTotais[nPos,2]
			EndIf
	
			DbSelectArea("SA1")
			DbSetOrder(1)
			If DbSeek(xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA)
				nSalCli  := 0
				nLimCred := 0
				nLimCred := SA1->A1_LC
			EndIf
	
			nPERLIMMAX := ((nLimCred * nMVLIMMAX) / 100)
	
			nSalCli := nTitAbertos + nValorCompra
			nLimMax := nLimCred + nPERLIMMAX
	
			//ANALISE DE LIMITE DE CR�DITO
			// Verifica se a compra+saldo > Limite Cred + Tolerancia e menor que limite m�ximo, ent�o, pede senha
			If nSalCli > nLimCred
				If  nSalCli < nLimMax
		//			cMsgStatus
					cMsgStatus += "Valor ultrapassou o Limite de Cr�dito de: " + TRANSFORM(nLimCred,"@E 999,999.99")+CRLF
					cMsgStatus += "Total da compra + t�tulos em aberto: "+ TRANSFORM(nSalCli,"@E 999,999.99")+ CRLF
					cMsgStatus += "_________________________________________________" + CRLF
					If lTitVencido .or. lObsBlq
						cMsgTitulo  := cMsgTitulo +  " e por Limite de Cr�dito"
					Else
						cMsgTitulo  := "Bloqueio por Limite de Cr�dito"
					EndIf
					If !lTitVencido
						lPedeSenha := .T.
					EndIf
					lBlocCred  := .T.
					lShowErro  := .T.
				ElseIf nSalCli > nLimMax
					cMsgStatus += "Valor ultrapassou o Limite M�ximo de: " + TRANSFORM(nLimCred,"@E 99,999.99")+ " + " + TRANSFORM(nMVLIMMAX,"@E 999") + "% = " + TRANSFORM(nLimMax,"@E 99,999.99") + CRLF
					cMsgStatus += "Total da compra + t�tulos em aberto: "+ TRANSFORM(nSalCli,"@E 999,999.99")+ CRLF
					cMsgStatus += "_______________________________________________________" + CRLF
					If lTitVencido .or. lObsBlq
						cMsgTitulo  := cMsgTitulo +  " e por Limite de Cr�dito"
					Else
						cMsgTitulo  := "Bloqueio por Limite de Cr�dito"
					EndIf
					lPedeSenha := .F.
					lBlocCred  := .T.
					lShowErro  := .T.
				EndIf
				lLim		:= .T.
			EndIf
	
			//Mostra mensagem
			If !lPedeSenha .and. (lTitVencido .or. lBlocCred .or. lObsBlq)
				cMsgStatus += "Favor entrar em contato com o Financeiro."
				lRet := .F.
				MSGALERT(cMsgStatus,cMsgTitulo )
				Return lRet
			ElseIf lPedeSenha .and. (lTitVencido .or. lBlocCred .or. lObsBlq)
				cMsgStatus += "A senha do gerente ser� exigida." + CRLF
				lPedeSenha := .T.
				MSGALERT(cMsgStatus,cMsgTitulo)
			EndIf
	
			// Exibe a tela de senha
			If lPedeSenha
				If FAT004(cMsgStatus)	// Se acertar senha, confirma gravacao
					lRet := .T.
					If AllTrim(cEmpAnt) <> "03"
						dbSelectarea("SZB")
						dbSetOrder(5)
						If .not. SZB->(dbSeek(xFilial("SZB")+M->LQ_NUM))
							RecLock("SZB",.T.)
						Else
							RecLock("SZB",.F.)
						EndIF
						ZB_FILORC   := cFilAnt
						ZB_CLIENTE  := M->LQ_CLIENTE
						ZB_LOJA 	:= M->LQ_LOJA
						ZB_USUARIO  := cCodUse
						ZB_ORCA 	:= M->LQ_NUM
						ZB_LC 		:= nLimCred
						ZB_SALDO 	:= nSalCli
						ZB_DATA 	:= M->LQ_EMISSAO
						//	ZB_VENCI 	:= cVctMaisAnt
						ZB_MSG 	:= cMsgStatus
						Do Case
						Case lAtraso .AND. !lLim		//Se for s� atraso
							ZB_MOTIVO	:= "Bloqueio por atraso"
						Case !lAtraso .AND. lLim		//Se for s� limite
							ZB_MOTIVO	:= "Bloqueio por limite de credito"
						Case lAtraso .AND. lLim			//Se for atraso e limite
							ZB_MOTIVO	:= "Bloqueio por atraso e limite de credito"
						EndCase
						SZB->(MsUnlock())
						SZB->(dbCloseArea())
					EndIf
				Else	// se pressionar Cancela ou errar Senha, n�o grava
					lRet := .F.
				EndIf
			EndIf
		EndIf
	EndIf

	//validar�se�a�separa��o�j�foi�realizada�e�autorizar�a�finaliza��o�da venda
	if nVar == 2 .and. lRet
	// IF�nVar == 2 .AND. lRet
��������IF ! ( lRet�:=�u_RomaneOk( SL1->L1_YROMAN, SL1->L1_YSEQROM ) == "30"�) //Verifica se a separa��o foi finalizada e libera a venda se for o caso
			Aviso( "ATEN��O!", "O romaneio ainda n�o foi separado.", { "Ok" } )
		ENDIF
	ENDIF

	//validar�se o romaneio est� na fase 10 (Solicita��o), antes de permitir a altera��o
	IF nVar == 1 .and. lRet
	// IF�nVar == 1 .AND. lRet 
		IF  ! ( lRet�:=�u_RomaneOk( SL1->L1_YROMAN, SL1->L1_YSEQROM ) == "10"�) //Verifica se N�O houve separa��o e libera a altera��o e ou exclus�o
			Aviso("ATEN��O!", "O romaneio j� foi separado ou est� sendo. Solicite o estorno.", { "Ok" })
		ENDIF		
����ENDIF	

Return lRet

/*
------------------------------------------------------------------------------------------------------------
Fun��o		: FAT004(cMsgStatus)
Tipo		: Fun��o Est�tica
Descri��o	: Fun��o respons�vel por criar a tela para aplica��o da senha, caso seja chamada
Chamado     : Antes de gravar a venda
Par�metros	: 
Retorno		: L�gico
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 17/01/2012 - Henrique - Constru��o inicial do fonte
- 02/08/2013 - Sandro - Ajuste para adequar ao cliente
- 09/04/2019 - Ronilson Rodrigues - Altera��o parcial do c�digo
- 10/04/2019 - Ronilson Rodrigues - Ajuste da apar�ncia desta tela
------------------------------------------------------------------------------------------------------------
*/

Static Function FAT004(cMsgStatus)

	Local cSenha		:= Space(20)
	Local cOcorrencia	:= cMsgStatus
	Local oDlg2
	Local oMemo
	Local oBold
	Private oBotao
	Private cUsua		:= Space(20)
	Private lVal 		:= .F.
	
	// Caso o usu�rio logado n�o possua superiores, ser� informado e n�o deixar� finalizar a venda
	If Len(FWSFUsrSup(RetCodUsr())) == 0
		MsgAlert("O usu�rio " + AllTrim(cUserName) + " n�o possui superior. " + Chr(13) + Chr(10) + "Favor informar ao setor de TI.","Aten��o!")
		Return lVal
	Else
		DEFINE MSDIALOG oDlg2 TITLE "Solicita��o de Senha" FROM 000,000 TO 330, 500 PIXEL
	
		DEFINE FONT oBold NAME "Arial" SIZE 0, 140 BOLD
	
		oPanel := TPanel():New(0,0,'',oDlg2,, .T., .T.,, ,oDlg2:nWidth-5,55,.T.,.T. )
		oPanel:Align := CONTROL_ALIGN_TOP // Somente Interface MDI
	
		oPanel2 := TPanel():New(25,0,'',oDlg2,, .T., .T.,, ,100,150,.T.,.T. )
		oPanel2:Align := CONTROL_ALIGN_TOP // Somente Interface MDI
	
		@ 10,005 SAY "Senha:" SIZE 070,07 OF oPanel PIXEL
		@ 20,005 MSGET cSenha PASSWORD SIZE 90,7  PIXEL OF oPanel
		
		@ 35,005 BUTTON oBotao PROMPT "Confirma" 	SIZE 40,10 PIXEL OF oPanel ACTION {||iif(FAT005(cUsua, cSenha, @lVal), oDlg2:End(), )}
		@ 35,050 BUTTON oBotao PROMPT "Cancela" 	SIZE 40,10 PIXEL OF oPanel ACTION {lVal := .F., oDlg2:End()}
	
		@ 05,005 SAY "Ocorr�ncia:" SIZE 070,07 OF oPanel2 PIXEL
		@ 13,005 Get oMemo Var cOcorrencia Memo Size (oDlg2:nWidth/2)-10, 90 When .F. Of oPanel2 Pixel
	
		ACTIVATE MSDIALOG oDlg2 CENTERED
	EndIf
Return lVal

/*
------------------------------------------------------------------------------------------------------------
Fun��o		: FAT005(cUsua, ccSenha, lVal)
Tipo		: Fun��o Est�tica
Descri��o	: Valida a senha dos superiores do usu�rio
Chamado     : Antes de gravar a venda
Par�metros	: 
Retorno		: L�gico
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 17/01/2012 - Henrique - Constru��o inicial do fonte
- 02/08/2013 - Sandro - Ajuste para adequar ao cliente
- 09/04/2019 - Ronilson Rodrigues - Altera��o parcial do c�digo
------------------------------------------------------------------------------------------------------------
*/

Static Function FAT005(cUsua, ccSenha, lVal)
	Local cCodAnt 	:= ""
	Local nOpca		:= 0
	Local lblAviso
	Static cCodUse 	:= ""
	Private aLista 	:= {}
	Private aUsuSup := {}
	Private oListBox
	Private cVar 	:= ""
	Private cCod	:= ""

	cCodAnt := RetCodUsr()
	aUsuSup	:= FWSFUsrSup(RetCodUsr())
	
	DEFINE DIALOG oDlg2 TITLE "Superiores Autorizados" FROM 000,000 TO 330,770 PIXEL

	// Vetor com elementos do Browse
	oDLG2:lMAXIMIZED	:= .F.
	oDLG2:lCENTERED		:= .T.
	
	ShowAvisos(aLista)
	
	If Len(aLista) == 0
		MsgStop("Informe ao setor de TI que n�o h� superiores habilitados para este usu�rio.")
		oDlg2:End()
		Return .F.
	EndIf
	
	@ C(005), 0005 SAY lblAviso PROMPT "Superiores" SIZE 100, 007 OF oDLG2 COLORS CLR_HBLUE PIXEL

	ACTIVATE MSDIALOG oDlg2 CENTERED ON INIT EnchoiceBar(oDlg2,;
		{||	nOpca := 1, oDlg2:End()},;
		{||	nOpca := 2, oDlg2:End()})
	
	If nOpca == 2
		Return .F.
	EndIf
	
	/*
	0 (zero) - usu�rio pertence ao grupo de Administradores
	1 - usu�rio n�o pertence ao grupo de Administradores
	2 - usu�rio n�o encontrado
	3 - arquivo de senha sendo utilizado por outra esta��o
	*/
	// RetCodUsr() //ID do usuario corrente
	lVal := .T.
	PswOrder(1)
	If PswSeek(cCod, .T.)
		cCodUse = cCod
		If !PswName(ccSenha)
			lVal := .F.
			MsgStop("Senha n�o confere. Favor verificar.")
		EndIf
	EndIf
	
	PswOrder(1)
	PswSeek(cCodAnt, .T.)
Return lVal

/*
------------------------------------------------------------------------------------------------------------
Fun��o		: ShowAvisos(aLista)
Tipo		: Fun��o Est�tica
Descri��o	: Adiciona � lista os superiores do usu�rio vd utilizado
Chamado     : Ao digitar senha e confirmar
Par�metros	: 
Retorno		: 
------------------------------------------------------------------------------------------------------------
Atualiza��es:
- 17/01/2012 - Henrique - Constru��o inicial do fonte
- 02/08/2013 - Sandro - Ajuste para adequar ao cliente
- 09/04/2018 - Ronilson Rodrigues - Altera��o parcial do c�digo
------------------------------------------------------------------------------------------------------------
*/

Static Function ShowAvisos(aLista)
	Local nI		:= 0
	Local cGrpUser	:= ""
	Local cGrpId	:= ""
	Local aGrpUser	:= AllGroups()
	
	For nI := 1 To Len(aGrpUser)
		cGrpId := Iif((AllTrim(aGrpUser[nI,1,2])) == "VENDEDORES", aGrpUser[nI,1,1],)
	Next nI
	
	PswOrder(1)
	For nI := 1 to Len(aUsuSup)
		cGrpUser := Iif(Len(UsrRetGrp(,aUsuSup[nI])) > 0, UsrRetGrp(,aUsuSup[nI])[1],)
		
		If PswSeek(aUsuSup[nI], .T.)
			If lSenhaVend
				If AllTrim(cGrpUser) == AllTrim(cGrpId)
					aAdd(aLista, {PswRet()[1][4], PswRet()[1][1]}) 	// Nome Completo, Codigo
				EndIf
			Else
				If AllTrim(cGrpUser) <> AllTrim(cGrpId)
					aAdd(aLista, {PswRet()[1][4], PswRet()[1][1]}) 	// Nome Completo, Codigo
				EndIf
			EndIf
		EndIf
	Next nI
	
	@ 020, 005 LISTBOX oListBox VAR cVar FIELDS HEADER "NOME", "CODIGO" SIZE 382, 120 OF oDlg2 PIXEL
		
	oListBox:BCHANGE := {|| cCod := aLista[oListBox:nAt,2]}
	oListBox:SetArray(aLista)
	oListBox:bLine := {|| {aLista[oListBox:nAt,1], aLista[oListBox:nAt,2]}}
Return

// //Fun��o�criada�para�validar�se�a�separa��o�j�foi�finalizada�e�autorizar�a�finaliza��o�do�or�amento
// User Function u_RomaneOk( cCodRom, cCodSeq, cFase )�

// 	Local lOk := .F.
// 	Default cFase := "10"
	
// 	cFase := FormatIn(cFase,"|")

// 	IF SELECT( 'qryZZ1' )
// 		qryZZ1->(DBCLOSEAREA())
// 	ENDIF

// 	//VERIFICA SE O ROMANEIO EST� SENDO SEPARADO
// 	BEGIN ALIAS 'qryZZ1'
// 		SELECT TOP 1 1 ROMAOK
// 		FROM %table:ZZ2% (NOLOCK) Z2
// 		INNER JOIN %table:ZZ1% (NOLOCK) Z1 ON ZZ1_ROMAN = ZZ2_ROMAN AND  ZZ1_SEQROM = ZZ2_SEQROM AND ZZ2_FILIAL = ZZ1_FILIAL
// 		WHERE ZZ2_FILIAL = %xFilial:ZZ1%
// 		  AND Z2.D_E_L_E_T_ = ''  
// 		  AND Z1.D_E_L_E_T_ = '' 
// 		  AND ZZ1_FASE IN %Exp:cFase%//FASE DO ROMANEIO, ONDE 20 E 30 S�O RESPECITIVAMENTE "EM SEPARA��O" E "SEPARADO".
// 		  AND ZZ2_ROMAN = %Exp:cCodRom%
// 		  AND ZZ2_SEQROM = %Exp:cCodSeq%
// 	ENDSQL

// 	lOk := qryZZ1->ROMAOK == 1

// 	qryZZ1->(DBCLOSEAREA())

// Return lOk

