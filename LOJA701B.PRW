#INCLUDE "LOJA701B.CH"
#INCLUDE "PROTHEUS.CH"
#INCLUDE "TCBROWSE.CH"

#DEFINE VALOR_DESCONTO 3		// Posicao do valor do desconto no array aDesconto
#DEFINE _MOEDA		6  			//Posicao do campo Moeda no array aPgtos(Localizacoes)
#DEFINE _EMISSAO	7  			//Posicao do campo Data de emissao no array aPgtos(Localizacoes)
#DEFINE _FORMATEF	"CC;CD"     //Formas de pagamento que utilizam operação TEF para validação
#DEFINE TEF_SEMCLIENT_DEDICADO  	"2"     //Utiliza TEF Dedicado Troca de Arquivos
#DEFINE TEF_COMCLIENT_DEDICADO  	"3"		//Utiliza TEF Dedicado com o Client
#DEFINE TEF_DISCADO             	"4"		//Utiliza TEF Discado
#DEFINE TEF_LOTE                	"5"		//Utiliza TEF em Lote
#DEFINE TEF_CLISITEF				"6"		//Utiliza a DLL CLISITEF

Static aMoeda
Static _nHeight
Static	lAtuCond
Static lAtuPgto 	:= .F.
Static lDesSelNCC	:= .F.						// Variavel para verificar se a NCC foi selecionada e depois (F7)(F7) nao foi selecionada novamente
Static lLjDespa		:= SuperGetMv("MV_LJDESPA",,.F.)					// Habilita desconto por Adm e banco
Static aDadosF3 	:= {}
Static lNovRegDesc 	:= SuperGetMv("MV_LJRGDES",,.F.) .AND. RGVldTable()		//Indica se usa nova regra de desconto
Static lCalcFrete	:= .T. 		//Variavel de controle, com o objetivo de nao somar mais de uma vez o frete no valor total
Static aRetLj7T		:= {}												// Armazena os valores do rodape (Lj7T_)
Static nPerRDAnt 	:= 0	// Percentual de desconto anterior (utilizado na nova Regra de Desconto Varejo)
Static aVldVencPc 	:= { }	// controlará o recálculo do vencimento baseado na Adm Financeira e id do cartão forma: { 'id-1', 'id-2' }
Static aAdmsFinRG 	:= {} 	// Armazena as Adm. Financeiras (CC/CD) quando utilizada a Regra de Desconto Varejo (Estrutura: { Cod. Adm. Fin, IdCartao } )
Static nIPIEC		:= 0	//Valor do IPI com Frete
Static aTx_Juros 	:= {0,0,0,0}   // Armazena a taxa de juros dos cartoes
Static cLj7TrcForm  := "" //troco da forma de pagamento
Static cLj7NumTrc 	:= "" //Venda da forma de pagamento
Static nValRetISS	:= 0	//Retencao de Imposto ISS
Static nOpcRotina	:= 1	// Opcao da funcao a Rotina

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ Lj7DefPag ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Rotina para definicao do pagamento						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7DefPag(lExp1, oExp2, oExp3, aExp4) 		              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ lExp1 - Define se e para criar os objetos 				  ³±±
±±³          ³ oExp2 - Objeto que contera o Panel						  ³±±
±±³          ³ oExp3 - Objeto que contem a dialog principal (LOJA701)	  ³±±
±±³          ³ aExp4 - Array que contem a posicao do Panel				  ³±±
±±³          ³ nExp5 - Numero da operacao do sistema      				  ³±±
±±³          ³ lExp2 - Indica se possui TEF Pendente CLISITEF       	  ³±±
±±³          ³ nExp2 - Guarda a transacao TEF que foi aprovada            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7DefPag(	lCria		, oPanVA3	, aPosObj4	, oEncVA	,;
					nOpc 		, lTefPendCS, aTefBKPCS	, cAlterCond,;
					lDefPagto	, nVlrAcrsFi, lRegraDesc, nPerDesc	,;
					aDadosCNeg	)

Local aObjectsPg	:= {}																	   		// Array dos objetos do Painel da cond. de pagto
Local aPosObjPg		:= {}																			// Array com a posicao dos objetos da tela
Local aArea			:= { 0, 0, aPosObj4[2,3], aPosObj4[2,4], 2, 2 }								// Area dos objetos na tela
Local nX            := 0																	  		// Variavel usada em lacos For...Next
Local lLj7011		:= ExistBlock("LJ7011")													  		// Indica se existe o PE LJ7011
Local lLj7012		:= ExistBlock("LJ7012")													   		// Indica se existe o PE LJ7012
Local lContinua 	:= .T.																	   		// Indica se continua a execucao da funcao
Local nPosDtDProp   := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO"})				// Posicao do campo Data no aColsDet
Local nPosVlItem    := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]   	// Posicao do Valor Total do Item
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local bPgtosDblClick                                                						   		// Bloco de codigo ao dar duplo clique no grid de parcelas
Local bBloco        := {|| NIL }                                    						   		// Bloco de codigo executado quando tenta mudar a forma de pagamento para Lay-Away
Local oPanVAPg                                                      						   		// Objeto do panel da condicao de pagamento
Local oPanCondNeg                                                   						   		// Objeto do panel da condicao negociada
Local cCond         := ""                                           						   		// Condicao de pagamento da venda
Local cCondPad      := SuperGetMV( "MV_CONDPAD" )                   						   		// Condicao de pagamento padrao
Local nLJValPIS 	:= 0                                            						   		// Valor do PIS da venda
Local nLJValCof 	:= 0                                            						   		// Valor do CONFINS da venda
Local nLJValCSL 	:= 0                                           									// Valor do CSLL da venda
Local lHomol		:= .F.                                         									// Uso interno da Microsiga
Local nTotVenda  	:= 0																			// Valor total da venda
Local lUsafd      	:= SuperGetMV("MV_LJUSAFD",,.F.) 												// Utiliza Fidelizacao de cliente ??
Local lLog4         := Subs(LJGetProfile("LOGERRO"),4,1) == "S" 									// Log de Recuperacao, grava as parcelas
Local lLj7031		:= ExistBlock("LJ7031")															// Verifica a existencia do PE LJ7031
Local lPanVA3		:= .F.																			// Define se o Painel de Pagamentos esta visivel
Local nMV_LJCPNCC   := SuperGetMV("MV_LJCPNCC",,1) 													// Parametro que define a forma de baixa da NCC na compensacao
Local nTamCondPg	:= TamSX3("L1_CONDPG")[1]													    // Tamanho do Campo L1_CONDPG
Local lAltCond      := .F.																			// Verifica se foi alterada a condicao de pagamento
Local lTemGeraNOrc	:= .F.							       											// Se tem funcao de geracao de numero de orcamento diferente
Local lObrigatorio	:= .T.																			//Se os campos obrigatorios estao preenchidos
Local lAtuList      := .T. 																			//Define se atualiza list box de parcelas
Local nTamL4_FORMAID  	:= 0
Local nTamL4_CHEQUEID	:= IIf(SL4->(ColumnPos("L4_CHEQID"))>0,TamSx3("L4_CHEQID")[1],1)				// Tamanho do campo L4_CHEQID
Local cEnvelopes    := ""
Local nPosEnvelo    := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ENVELO"})					// Posicao do campo com o codigo o envelope no aColsDet
Local nCont			:= 1																			// Contador do For
Local lMV_LJRest   	:= SuperGetMV("MV_LJREST",,.F.) 										    	// Utiliza ambiente de Restaurante?
Local lAutoExB		:= IsBlind()																	// Verifica se a rotina sera executada via execauto ou nao
Local lTemICMSol	:= .F.						//Verifica se a venda tem ICMS Solidario
Local nIcmSolDif	:= 0						//Diferenca do valor do ICMS solidario COM ou SEM frete
Local nValFrete		:= 0						// Valor do Frete
Local lFTVD7011		:= ExistBlock("FTVD7011")													  		// Indica se existe o PE FTVD7011
Local lFTVD7012		:= ExistBlock("FTVD7012")													   		// Indica se existe o PE FTVD7012
Local lFTVD7031		:= ExistBlock("FTVD7031")															// Verifica a existencia do PE FTVD7031
Local cOrigem       := IIf(SL1->(ColumnPos("L1_ORIGEM"))>0,SL1->L1_ORIGEM,"")  							// variavel da gestão de concessionarias
Local cVeicTip		:= IIf(SL1->(ColumnPos("L1_VEICTIP"))>0,SL1->L1_VEICTIP,"")							// variavel da gestão de concessionarias
Local nOpca         := 0
Local lOrcFinali 	:= !Empty(SL1->L1_DOC) .OR. !Empty(SL1->L1_DOCPED)								//Verifica se orcamento esta finalizado
Local nDescFIN		:= IIf( nOpc==2 .And. !lOrcFinali, SL1->L1_DESCFIN, 0 ) 						//Desconto Financeiro da condicao de pagamento (resgata o desc. Financeiro quando for nOpc=2 "Visualizacao")
Local lHabTroco     := SuperGetMV( "MV_LJTROCO", ,.F. )   //Determina que o controle de troco esta habilitado
Local lLjNCCOr		:= SuperGetMv("MV_LJNCCOR", Nil, .F.)	//verifica se a NCC sera mantida no orcamento (F4)
Local lImpOrc		:= IsinCallStack("lj7vldCarrega") .AND. lLjNCCOr
Local lECommerce	:= SuperGetMV("MV_LJECOMM",,.F.) .AND. ( SL1->((ColumnPos("L1_ECFLAG") > 0) .AND. (L1_ECFLAG == "1")) )   //PEDIDO E-COMMERCE
Local lMvLjIPEn		:= SuperGetMV("MV_LJIPENP",, .F.)
Local lMaFisFound	:= .F.
Local oSayRetImp	:= Nil	//Retencao de Imposto ISS
Local lECCia		:= SuperGetMV("MV_LJECOMO",,.F.) //e-commerce ciashop habilitado
Local lAltaPgtos    := SuperGetMV( "MV_LJALTAP",,.F.) //Permite alteração do aPgtos apos escolha da condição de pagameto na finalização da venda
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD() //Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default lCria 			:= .F.
Default lDefPagto		:= .F.																			// Verifica se passou pela tela de definição de pagamentos
Default nVlrAcrsFi  	:= 0 																			// variavel para calculo de juros sobre o valor financiado
Default lRegraDesc  	:= .F.																			// Variavel para controlar se vai aplicar a regra de desconto
Default nPerDesc		:= 0 																			// Variavel que retorna o percentual de desconto
Default aDadosCNeg		:= {}
Default aTefBKPCS		:= {}

Static aLayPgtos    	:= {}																			// Array com as formas de pagamento para mudar o Action dos botoes na finalizacao do Lay-Away
Static lVoltaF7 		:= .F. //Variavel para controlar se estah retornando a tela dos itens quando pressionado F7

LjSetnOpcRot( nOpc )

//Se NAO for Visualizacao e alguma consulta padrao F3 estiver aberta, nao deixamos que a consulta seja executada
If Type("InConPad") <> "U" .AND. InConPad .AND. nOpc <> 2
	Return .F.
EndIf

aTx_Juros := {0,0,0,0}

lCalcFrete := .T.

//Se for visualização de pedido e-commerce, salva os Totais  para exibição na tela
If nOpc == 2 .AND.  !lCria .AND. ( lECommerce  .AND. !lECCia) .AND.  (Type("lAutoExec") <> "L" .OR. !lAutoExec) .AND. !Empty(SL1->L1_ORCRES)
	oPgtos:Hide()
	oPgtosSint:Hide()
EndIf

/*ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Quando for a Nova Regra de Desconto, armazenamos os valores do rodape quando o usuario escolher uma	³
//³forma de pagamento, pois pode ser necessario restaura-los se o usuario clicar no botal Cancelar		³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ*/
If lNovRegDesc .AND. !lCria
	If lVoltaF7 .And. Len(aRetLj7T) > 0 .And. aRetLj7T[1] == M->LQ_NUM
		//Restaura os valores originais do array aTotais. (Usado somente quando for a nova regra de desconto varejo)
		LjRetLj7T()
	Else
		//Verifica se existe icms solidario no item, caso afirmativo, soma o valor
		lTemICMSol :=  MaFisFound("NF").AND. MaFisRet(,"NF_VALSOL") > 0 
		
		If lTemICMSol .AND. lCalcFrete

			// Incluir o valor de frete no total da venda
			nValFrete := Lj7CalcFrete( ,lTemICMSol, @nIcmSolDif )								
			lCalcFrete := .F. //Seta a variavel para .F. para que nao seja somado novamente o valor do frete no valor total dentro da funcao Lj7AjustaTroco

            LJ7T_SubTotal( 2, MaFisRet(,"NF_TOTAL") + IIf(ExistFunc("LjNewCalSol") .And. LjNewCalSol(),Lj7T_DescV(2),0 ) - (nValFrete ) )
			
			LJ7T_Total( 2, Lj7T_Subtotal(2) + aAcrescimo[1] - Lj7T_DescV(2) + nValFrete )
		EndIf

		LjSetLj7T( 1, M->LQ_NUM, Lj7T_SUBTOTAL(2), Lj7T_DESCP(2), Lj7T_DESCV(2), Lj7T_TOTAL(2) )
		lVoltaF7 := .F.
	EndIf
	lVoltaF7 := !lVoltaF7
EndIf
																									// dos botoes na finalizacao do Lay-Away
If !lCria .AND. lLj7031 .AND. !lFtvdVer12
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se existir o PE LJ7031, guarda  ³
	//³a origem da chamada da funcao.  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Quando igual a .T., foi chamado a partir da Tela de Definicao de Pagamentos³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	lPanVA3 := oPanVA3:lVisible
EndIf

LjGrvLog(M->LQ_NUM,Chr(10)+Chr(13)+"PRESSIONOU F7 OU FINALIZAR VENDA")

If !lCria .AND. lFTVD7031 .AND. lFtvdVer12
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se existir o PE FTVD7031, guarda³
	//³a origem da chamada da funcao.  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Quando igual a .T., foi chamado a partir da Tela de Definicao de Pagamentos³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	lPanVA3 := oPanVA3:lVisible
EndIf

If !lCria
	lDefPagto	:= .T.

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se nao informou midia e for obrigatorio chama funcao para informar   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nOpc <> 2 .AND. SuperGetMv("MV_LJRGMID",,0) == 2 .AND. ExistFunc("LjxValMid") .AND. LjxValMid()
		While Empty(M->LQ_MIDIA)
			M->LQ_MIDIA:= LjxGetMid(M->LQ_MIDIA)  // Midia
		End
	EndIf

EndIf

lAtuCond   := .T.
cAlterCond := M->LQ_CONDPG			// Guarda a condicao de pagamento padrao

If ExistFunc("U_LJHOMTEF") .AND. LjMSSM0(SM0->M0_CGC)
	lHomol := .T.
EndIf

lMaFisFound := MaFisFound("NF")

If lMaFisFound
	nLjValPis := MaFisRet(,'NF_VALPIS')
	nLjValCof := MaFisRet(,'NF_VALCOF')
	nLjValCsl := MaFisRet(,'NF_VALCSL')

	If nLJValPIS <= SuperGetMV("MV_VRETPIS")
		nLJValPis := 0
	EndIf
	If nLJValCof <= SuperGetMV("MV_VRETCOF")
		nLJValCof := 0
	EndIf
	If nLJValCSL <= SuperGetMV("MV_VRETCSL")
		nLJValCSL := 0
	EndIf

	LJPCCIni( M->LQ_CLIENTE, M->LQ_LOJA, dDataBase)
	LJPCCAlt("SL", { Lj7T_Subtotal(2), nLJValPIS, nLJValCof, nLJValCSL })
EndIf

If lCria

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Definicao do painel que irah conter as formas de pagto e     ³
	//³ os botoes para escolha das formas                            ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	oPanVA3	:= TPanel()		:New(	aPosObj4[2,1]	, aPosObj4[2,2]		, ""				, oDlgVA	,;
									Nil				, .T.				, .F.				, Nil		,;
									Nil				, aPosObj4[2,3]		, aPosObj4[2,4]		, .T.		,;
									.F. )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Definicao da posicao dos objetos  que estarao contidos no    ³
	//³ Painel da condicao de pagamento                              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aAdd( aObjectsPg, { 100, 100, .T., .T. })
	aAdd( aObjectsPg, { 100, 100, .T., .T. })

	aPosObjPg := MsObjSize( aArea, aObjectsPg, .T., .T. )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Definicao dos objectos contidos no painel da cond. pagto     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	oPanVAPg 	:= TPanel()	:New( aPosObjPg[1,1], aPosObjPg[1,2], "", oPanVA3, Nil, .T., .F.,;
								 Nil, Nil, aPosObjPg[1,4]-aPosObjPg[1,2], (aPosObjPg[1,3]-aPosObjPg[1,1]), .T., .F. )

	oPanCondNeg := TPanel()	:New( aPosObjPg[1,1], aPosObjPg[1,2], "", oPanVA3, Nil, .T., .F.,;
								 Nil, Nil, aPosObjPg[1,4]-aPosObjPg[1,2], (aPosObjPg[1,3]-aPosObjPg[1,1]), .T., .F. )
	oPanCondNeg:Hide()
	oPanCondNeg:lReadOnly := .T.

	oPgtos 		:= TCBrowse()	:New( aPosObjPg[2,1], aPosObjPg[2,2], aPosObjPg[2,4]-aPosObjPg[2,2], aPosObjPg[2,3]-aPosObjPg[2,1]-15,;
								 Nil, Nil, Nil, oPanVA3, Nil, Nil, Nil, Nil, bPgtosDblClick,,,,,,,,, .T. )

	If lVisuSint
		oPgtosSint	:= TCBrowse()	:New( aPosObjPg[2,1], aPosObjPg[2,2], aPosObjPg[2,4]-aPosObjPg[2,2], aPosObjPg[2,3]-aPosObjPg[2,1]-15,;
								 Nil, Nil, Nil, oPanVA3, Nil, Nil, Nil, Nil, bPgtosDblClick,,,,,,,,, .T. )
	EndIf

	If cPaisLoc <> "BRA" .AND. SuperGetMV("MV_LJTRLOC") .AND. nMV_LJCPNCC <> 3
		_nHeight := oPgtos:nHeight

		LjCalcTrc("ASSISTIDA",,,oPanVA3,@aMoedas,@aTroco,aPosObjPg)

		oLBBaixa:Hide()
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria os objetos para Total Parcelas e Troco                  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If ! ( nOpc == 2 .AND.  lECommerce  .AND.  (Type("lAutoExec") <> "L" .OR. !lAutoExec) .AND. !Empty(SL1->L1_ORCRES) )
		//TOTAL PARCELAS
		@ aPosObjPg[2,3]-aPosObjPg[2,1]-8, aPosObjPg[2,2]+3	SAY aTotais[5, 5]	VAR aTotais[5, 1]								SIZE 100,08 OF oPanVA3	PIXEL 						FONT aFontes[2]
		@ aPosObjPg[2,3]-aPosObjPg[2,1]-8, aPosObjPg[2,2]+40	SAY aTotais[5, 3]	VAR Transform( aTotais[5, 2], aTotais[5, 4] )	SIZE 050,10 OF oPanVA3	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2]
		//TROCO
		@ aPosObjPg[2,3]-aPosObjPg[2,1]-8, aPosObjPg[2,2]+100	SAY aTotais[6, 5]	VAR aTotais[6, 1]								SIZE 100,08 OF oPanVA3	PIXEL 						FONT aFontes[2]
		@ aPosObjPg[2,3]-aPosObjPg[2,1]-8, aPosObjPg[2,2]+136	SAY aTotais[6, 3]	VAR Transform( aTotais[6, 2], aTotais[6, 4] )	SIZE 050,10 OF oPanVA3	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2]
        //RETENCAO IMPOSTO
        @ aPosObjPg[2,3]-aPosObjPg[2,1]-8, aPosObjPg[2,2]+180	SAY oSayRetImp		PROMPT IIF(nValRetISS > 0,"Ret. Imposto","");
        																															SIZE 100,08 OF oPanVA3	PIXEL RIGHT 				FONT aFontes[2]
        @ aPosObjPg[2,3]-aPosObjPg[2,1]-8, aPosObjPg[2,2]+260	SAY oSayRetImp		PROMPT IIF(nValRetISS > 0,Transform(nValRetISS,PesqPict("SL1","L1_VALISS")),""); 	
        																															SIZE 050,10 OF oPanVA3	PIXEL RIGHT COLOR CLR_HRED	FONT aFontes[2] 
	EndIf

	If nOpc <> 2
		If Empty(cOrigem)
	        If nOpc == 4 .AND. !Empty(SL1->L1_ORCRES) .AND. !Empty(SL1->L1_FILRES)
	            If lVisuSint
	                oPgtosSint:bLDblClick	:= { || Aviso( STR0001, STR0002,{STR0003} ) } 	//'Atenção'###'Não é permitida a alteração das formas de pagamento de um orçamento gerado com reserva.'###'Ok'
	            Else
	                oPgtos:bLDblClick		:= { || Aviso( STR0001, STR0002,{STR0003} ) } 	//'Atenção'###'Não é permitida a alteração das formas de pagamento de um orçamento gerado com reserva.'###'Ok'
	            EndIf
	        Else
	            If lVisuSint
	                //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	                //³Durante a homologação o sistema não deve permitir entrar na tela de detalhe da forma de pagamento devido a exibição do parcelamento³
	                //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	                If !lHomol
	                    oPgtosSint:bLDblClick	:= {|| If(!oPanCondNeg:lVisibleControl,Lj7AltPgSi( oPgtosSint:nAt, nOpc,lTefPendCS , aTefBKPCS),Nil) }
	                EndIf
	            Else
	                oPgtos:bLDblClick		:= {|| If(!oPanCondNeg:lVisibleControl,Lj7AltPgt( oPgtos:nAt, Nil , Nil, lTefPendCS ),Nil) }
	            EndIf
	        EndIf
		ElseIf AllTrim(cOrigem) == "V" .AND. AllTrim(cVeicTip) == "3" 
			If lVisuSint
				oPgtosSint:bLDblClick	:= { || Aviso( STR0001, STR0196,{STR0003} ) } 	//'Atenção'###"Não é permitida a alteração da forma de pagamento na gestao de concessionarias"###'Ok'
			Else
				oPgtos:bLDblClick		:= { || Aviso( STR0001, STR0196,{STR0003} ) } 	//'Atenção'###"Não é permitida a alteração da forma de pagamento na gestao de concessionarias"###'Ok'
			EndIf
		EndIf
	ElseIf AllTrim(cOrigem) == "V" .AND. AllTrim(cVeicTip) == "3"
		If lVisuSint
			oPgtosSint:bLDblClick	:= { || Aviso( STR0001, STR0196,{STR0003} ) } 	//'Atenção'###"Não é permitida a alteração da forma de pagamento na gestao de concessionarias"###'Ok'
		Else
			oPgtos:bLDblClick		:= { || Aviso( STR0001, STR0196,{STR0003} ) } 	//'Atenção'###"Não é permitida a alteração da forma de pagamento na gestao de concessionarias"###'Ok'
		EndIf		
    EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Estrutura do array aPgtos                                    ³
	//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
	//³ [1] - Data de pagamento das parcelas                         ³
	//³ [2] - Valor da parcelas                                      ³
	//³ [3] - Forma de Pagamento                                     ³
	//³ [4] - Codigo da Administradora financeira                    ³
	//³ [5] - Coluna Customizada pelo ponto de entrada LJ7012        ³
	//³ [6] - Moeda(Localizacoes)                                    ³
	//³ [7] - Data de emissao(Localizacoes)                          ³
	//| [8] - Sequencia para controle de múltiplas transaçõies		 |
	//| [9] - Sequencia para controle de multiplas transacoes Cheque |
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	oPgtos:SetArray( aPgtos )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³A validacao da 5 coluna abaixo foi efetuada devido a um       ³
	//³procedimento utilizado para atualizacao do ListBox, onde a    ³
	//³sintaxe que insere  uma nova coluna sao reprocessadas novamente
	//³sob efeito do comando Refresh(), sendo assim, o mesmo nao deve³
	//³ser desenvolvido dinamicamente.                               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lLj7012 .AND. !lFtvdVer12
		aColCustom := ExecBlock( "LJ7012",.F.,.F. )

		If aColCustom[2] == 1
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtos HEADER STR0004 			OEM DATA { || aPgtos[oPgtos:nAt,1] } 										ALIGN LEFT  SIZE 40 PIXEL //"Data"

		If aColCustom[2] == 2
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtos HEADER STR0145 			OEM DATA { || Transform(aPgtos[oPgtos:nAt,2],PesqPict("SL1","L1_VLRTOT")) } ALIGN RIGHT SIZE 50 PIXEL //"Valor Pago"

		If aColCustom[2] == 3
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtos HEADER STR0006 			OEM DATA { || aPgtos[oPgtos:nAt,3] } 										ALIGN LEFT  SIZE 20 PIXEL //"Forma Pgto"

		If aColCustom[2] == 4
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf
	ElseIf !lFtvdVer12
		ADD COLUMN TO oPgtos HEADER STR0004 			OEM DATA { || aPgtos[oPgtos:nAt,1] } 										ALIGN LEFT  SIZE 40 PIXEL //"Data"
		ADD COLUMN TO oPgtos HEADER STR0145		  		OEM DATA { || Transform(aPgtos[oPgtos:nAt,2],PesqPict("SL1","L1_VLRTOT")) } ALIGN RIGHT SIZE 50 PIXEL //"Valor Pago"
		ADD COLUMN TO oPgtos HEADER STR0006 			OEM DATA { || aPgtos[oPgtos:nAt,3] } 										ALIGN LEFT  SIZE 20 PIXEL //"Forma Pgto"
		If cPaisLoc <> "BRA"
		   ADD COLUMN TO oPgtos HEADER STR0078 			OEM DATA { || aPgtos[oPgtos:nAt,_MOEDA] } 									ALIGN LEFT  SIZE 20 PIXEL //"Moeda"
		   ADD COLUMN TO oPgtos HEADER STR0079			OEM DATA { || aPgtos[oPgtos:nAt,_EMISSAO] } 								ALIGN LEFT  SIZE 40 PIXEL //"Emissao"
		EndIf
	EndIf

	If lFTVD7012 .AND. lFtvdVer12
		aColCustom := ExecBlock( "FTVD7012",.F.,.F. )

		If aColCustom[2] == 1
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtos HEADER STR0004 			OEM DATA { || aPgtos[oPgtos:nAt,1] } 										ALIGN LEFT  SIZE 40 PIXEL //"Data"

		If aColCustom[2] == 2
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtos HEADER STR0145 			OEM DATA { || Transform(aPgtos[oPgtos:nAt,2],PesqPict("SL1","L1_VLRTOT")) } ALIGN RIGHT SIZE 50 PIXEL //"Valor Pago"

		If aColCustom[2] == 3
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtos HEADER STR0006 			OEM DATA { || aPgtos[oPgtos:nAt,3] } 										ALIGN LEFT  SIZE 20 PIXEL //"Forma Pgto"

		If aColCustom[2] == 4
			ADD COLUMN TO oPgtos HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtos:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf
	ElseIf lFtvdVer12
		ADD COLUMN TO oPgtos HEADER STR0004 			OEM DATA { || aPgtos[oPgtos:nAt,1] } 										ALIGN LEFT  SIZE 40 PIXEL //"Data"
		ADD COLUMN TO oPgtos HEADER STR0145		  		OEM DATA { || Transform(aPgtos[oPgtos:nAt,2],PesqPict("SL1","L1_VLRTOT")) } ALIGN RIGHT SIZE 50 PIXEL //"Valor Pago"
		ADD COLUMN TO oPgtos HEADER STR0006 			OEM DATA { || aPgtos[oPgtos:nAt,3] } 										ALIGN LEFT  SIZE 20 PIXEL //"Forma Pgto"
		If cPaisLoc <> "BRA"
		   ADD COLUMN TO oPgtos HEADER STR0078 			OEM DATA { || aPgtos[oPgtos:nAt,_MOEDA] } 									ALIGN LEFT  SIZE 20 PIXEL //"Moeda"
		   ADD COLUMN TO oPgtos HEADER STR0079			OEM DATA { || aPgtos[oPgtos:nAt,_EMISSAO] } 								ALIGN LEFT  SIZE 40 PIXEL //"Emissao"
		EndIf
	EndIf

	If lVisuSint
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Estrutura do array aPgtosSint                                ³
		//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
		//³ [1] - Forma de Pagamento                                     ³
		//³ [2] - Qtde de Parcelas da forma de pagto                     ³
		//³ [3] - Valor total desta forma de pagamento                   ³
		//| [4] - Sequencia para controle de múltiplas transaçõies		 |
		//³ [5] - Data da primeira parcela                               ³
		//³ [6] - Codigo da Administradora financeira                    ³
		//³ [7] - Sequencia para controle de multiplas transacoes Cheque ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		oPgtosSint:SetArray( aPgtosSint )

		ADD COLUMN TO oPgtosSint HEADER STR0004	OEM DATA { || aPgtosSint[oPgtosSint:nAt,5] } ALIGN LEFT  SIZE 40 PIXEL 	//"Data"
		ADD COLUMN TO oPgtosSint HEADER STR0006	OEM DATA { || aPgtosSint[oPgtosSint:nAt,1] } ALIGN LEFT  SIZE 40 PIXEL 	//"Forma Pgto"
		ADD COLUMN TO oPgtosSint HEADER STR0145	OEM DATA { || aPgtosSint[oPgtosSint:nAt,3] } ALIGN LEFT  SIZE 40 PIXEL  //"Valor Pago"
		ADD COLUMN TO oPgtosSint HEADER STR0040	OEM DATA { || aPgtosSint[oPgtosSint:nAt,2] } ALIGN LEFT  SIZE 40 PIXEL 	//"Parcelas"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Só inserir a coluna ID Cartão quando o cliente trabalhar com múltiplas transações TEF³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cPaisLoc == "BRA"
			If lUsaTef .AND. SuperGetMV("MV_TEFMULT")
				ADD COLUMN TO oPgtosSint HEADER STR0104	OEM DATA { || aPgtosSint[oPgtosSint:nAt,4] } ALIGN LEFT  SIZE 40 PIXEL  //"ID Cartão"
			EndIf
		Else
			If SuperGetMV("MV_TEFMULT")
				ADD COLUMN TO oPgtosSint HEADER STR0104	OEM DATA { || aPgtosSint[oPgtosSint:nAt,4] } ALIGN LEFT  SIZE 40 PIXEL  //"ID Cartão"
			EndIf
		EndIf
		If (cPaisLoc == "ARG") .AND. (SL4->(FieldPos("L4_CHEQID")) > 0)
			ADD COLUMN TO oPgtosSint HEADER STR0171	OEM DATA { || aPgtosSint[oPgtosSint:nAt,7] } ALIGN LEFT  SIZE 40 PIXEL  //"ID Cheque"
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Monta os botoes com as formas de pagamento                   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//L1_Origem = V significa que o Orçamento foi feito pelo modulo de Veiculos
	If AllTrim(cOrigem) == "V" .AND. nOpc <> 2 .AND. !lAutoExB .AND. AllTrim(cVeicTip) == "3"
		nOpca := nOpc
		nOpc := 2
	EndIf
	Lj7MontPg(	@oPanVAPg	, @oPanCondNeg	, aPosObjPg		, nOpc			,;
				@aLayPgtos	, @lTefPendCS	, @aTefBKPCS	, @cAlterCond	,;
				@nVlrAcrsFi	, @aDadosCNeg	)

	If nOpca <> 0 .AND. !lAutoExB
		nOpc := nOpca
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Esconde o objeto Panel, ou seja, aparece com a tela de vendas³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	oPanVA3:Hide()

ElseIf oPanVA3:lVisible

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Chama o ponto de entrada LJ7011 para controlar o acesso aos  ³
	//³ itens                                                        ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lLj7011 .AND. !lFtvdVer12
		lContinua := ExecBlock("LJ7011",.F.,.F.)
	EndIf

	If lFTVD7011 .AND. lFtvdVer12
		lContinua := ExecBlock("FTVD7011",.F.,.F.)
	EndIf

	If lContinua
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Esconde a tela de pagto, ou seja, aparece com a tela de vendas. ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		oPanVA3:Hide()

		If nOpc == 4
			lAtuPgto := .T.
		EndIf

		If  cPaisLoc == "BRA"
			If M->LQ_TPFRET $ "12" .AND. lMaFisFound //FOB
				MaFisAlt("NF_FRETE",   0)
				MaFisAlt("NF_DESPESA", 0)
				MaFisAlt("NF_SEGURO",  0)
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Restaura o Valor total da venda para o caso de este ter sido ³
			//³ alterado devido a uma condicao de pagamento com acrescimo ou ³
			//³ desconto.                                                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If Lj7GetSubTot() > 0
				Lj7T_Subtotal(2, Lj7GetSubTot())
			EndIf			
			nTotVenda := Lj7T_Subtotal(2) - Lj7T_DescV(2)			
			If CrdXint() .AND. lUsaFD
				Lj7T_TotPar(2, Lj7T_TotPar(2) - Lj7AtuPremio() )
				Lj7T_Subtotal( 2, Lj7T_Subtotal(2) - Lj7AtuPremio() )
				nTotVenda -=  Lj7AtuPremio(.T.)
			EndIf
			Lj7T_Total( 2, nTotVenda )
		Else
			If (aDadosJur[09] <> 0 .OR. aDadosJur[01] <> 0 .OR. Lj7T_Total(2) > Lj7T_Subtotal(2)) .AND. nOpc <> 2
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Zera o array aDadosJur³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If !lFtvdVer12
					AEval(aDadosJur,{|x,y| aDadosJur[y]:=0 })
					Lj7T_Total( 2, Lj7T_Subtotal(2) )
					Lj7ZeraPgtos()                      // Zera forma de pagamento
					aAcrescimo[1] := 0					// Valor do acrescimo
					aAcrescimo[2] := 0					// Percentual do acrescimo
				ElseIf lFtvdVer12
					AEval(aDadosJur,{|x,y| aDadosJur[y]:=0 })
					Lj7T_Total( 2, 0 )
					Lj7T_Subtotal( 2, 0 )
					For nX := 1 To Len(aCols)
						aColsDet[nX][nPosDtDProp] := 0
						MaFisAlt("IT_PRCUNI",aCols[nX][nPosVlUnit],nX)
						MaFisAlt("IT_VALMERC",aCols[nX][nPosVlItem],nX)
						Lj7RecalImp(nX,1)
					Next nX
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Restaura a tela e toolbar  							 		 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7PrepTV( .F., oEncVA )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta o titulo do TOTAL da venda / mercadorias              ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		LJ7T_Total( 1, STR0007 ) // "Total de Mercadorias"
		
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta os valores de PIS/COFINS caso Haja                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7PisCof()
	EndIf
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Grava o arquivo para recuperação³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	lTemGeraNOrc := LjTemGeraNOrc()

	//Checa a obrigatoriedade dos campos da enchoice e da getdados
	If (LjNfPafEcf(SM0->M0_CGC) .AND. !lTemGeraNOrc) .OR. (!LJAnalisaLeg(37)[1] .OR. !lTemGeraNOrc)
		lObrigatorio := lRecebe .OR. Obrigatorio( aGets, aTela )
	Else
		lObrigatorio := .T.
	EndIf

	If lLog4
		If Len(aCols) == 0
			If !lAutoExB
				MsgStop(STR0009) //"Não é possível finalizar a venda pois ainda não foi vendido nenhum produto."
			Else
				ConOut(STR0009) //"Não é possível finalizar a venda pois ainda não foi vendido nenhum produto."
			EndIf
			Return .F.
		EndIf
		
		If lRecebe .OR. (lObrigatorio .AND. Lj7TudOk()) //Checa se existe linha vazia
			If cPaisLoc == "BRA"
				If !lRecebe .AND. lMaFisFound
		    		If LJ7CORRIPI()
						LJ7T_Total( 2, aTotais[1][2])
					Else
						Lj7T_Total( 2, MaFisRet(nil, "NF_TOTAL"))
					EndIf
				EndIf
			EndIf

			LjDeLogR(M->LQ_NUM)
			
			If !lRecebe
				For nX := 1 To Len(aCols)
					If !aCols[nX][Len(aCols[nx])]
						LJGrLogR(M->LQ_NUM, aCols, nX)
					EndIf
				Next nX
			EndIf
		EndIf
	EndIf

	If lRecebe .OR. (lObrigatorio .AND. Lj7TudOk())
	    If cPaisLoc == "BRA"
	    	If !lRecebe .AND. lMaFisFound
	    		If LJ7CORRIPI()
					LJ7T_Total( 2, aTotais[1][2] + aAcrescimo[1] - Lj7T_DescV(2) + Lj7CalcFrete() - nDescFIN)
				Else
                    If (!lECommerce .AND. !lMvLjIPEn) .OR. lECCia
                    	nValFrete := Lj7CalcFrete(Nil, MaFisRet(,"NF_VALSOL") > 0 )
                    	
                    	If nOpc <> 2 .Or. (Empty(SL1->L1_DOC) .And. Empty(SL1->L1_DOCPED)) //Nao recalcular total na visualizacao de orcamento finalizado
                    		LJ7T_Total( 2, MaFisRet(, "NF_TOTAL") + aAcrescimo[1] - IIF(ExistFunc("LjNewCalSol") .And. LjNewCalSol() , 0 , Lj7T_DescV(2))  - nDescFIN - LjPCCRet() )
                    	EndIf
					Else
						Lj7CalcFrete(Nil, .T.)
						LJ7T_Total( 2, MaFisRet(, "NF_TOTAL") + aAcrescimo[1] - Lj7T_DescV(2) )
					EndIf
					lCalcFrete := .F.
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Mostra o objeto Panel, ou seja, a "tela" para definicao dos	 ³
		//³ pagamentos somente se houver venda.		                     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Lj7T_Total( 2 ) > 0
		
		    LJ7AjustaTroco()

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Habilita a tela de pagamento.                                ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			oPanVA3:Show()
			oPgtos:SetFocus()
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ajusta o subtotal do pedido.                                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !lRecebe
			   If Lj7GetSubTot() > 0
					If Lj7T_Subtotal(2) > 0 .AND. Lj7T_Subtotal(2) <> Lj7GetSubTot()
						Lj7SetSubTot(Lj7T_Subtotal(2))
					EndIf
					Lj7T_Subtotal(2, Lj7GetSubTot())
				ElseIf lMaFisFound
					If LJ7CORRIPI()
						LJ7T_Total( 2, aTotais[1][2] + aAcrescimo[1] - Lj7T_DescV(2) + Lj7CalcFrete() - nDescFIN)
					Else
						If !( cPaisLoc $ "ARG|MEX|PAR" )
							// Se a venda tiver Frete com ICMS Solidario, subtraimos esses valores do SubTotal
							If MaFisRet(,"NF_FRETE") > 0 .Or. MaFisRet(,"NF_SEGURO") > 0 .Or. MaFisRet(,"NF_DESPESA") > 0

								//se a venda possui ICMS Solidario, o valor de ICMS deve ser recalculado, pois o Frete altera a Base de Calculo
								lTemICMSol :=  MaFisRet(,"NF_VALSOL") > 0

								// Incluir o valor de frete no total da venda
								nValFrete := Lj7CalcFrete( ,lTemICMSol, @nIcmSolDif )
								
								LJ7T_SubTotal( 2, MaFisRet(,"NF_TOTAL") + IIf(ExistFunc("LjNewCalSol") .And. LjNewCalSol(),Lj7T_DescV(2),0 ) - nValFrete )
								
								lCalcFrete := .F. //Seta a variavel para .F. para que nao seja somado novamente o valor do frete no valor total dentro da funcao Lj7AjustaTroco
								
								If (nOpc == 2 .And. !Empty(SL1->L1_DOC) .OR. !Empty(SL1->L1_DOCPED) .OR. !Empty(SL1->L1_PEDRES) )
                                	LJ7T_Total( 2, Lj7T_Subtotal(2) + nValFrete)
                                Else
                                	LJ7T_Total( 2, Lj7T_Subtotal(2) + aAcrescimo[1] - Lj7T_DescV(2) + nValFrete + nIcmSolDif )
                                EndIf																
							Else
                                LJ7T_SubTotal( 2, MaFisRet(,"NF_TOTAL") + IIf(ExistFunc("LjNewCalSol") .And. LjNewCalSol(),Lj7T_DescV(2),0 ) )								
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica se ha desconto e se foi dado depois da condicao de  ³
			//³ pagamento, caso afirmativo, faz o acerto dos totais          ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aDesconto[1] == 2
				Lj7T_DescP( 2, aDesconto[2] )
				Lj7T_DescV( 2, aDesconto[3] )
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica se o desconto foi efetuado antes ou depois da condi-³
			//³ cao de pagamento para acertar o total da venda               ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cPaisLoc == "BRA"
				If GetNewPar("MV_LJREST", .F.)
					If ExistFunc("LjRestTotal")
						LjRestTotal(@aAcrescimo)
					EndIf
				Else
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Se for finalizacao da venda e Condicao Negociada³
					//³com Acrescimo, efetua o recalculo do Acrescimo. ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If nOpc == 4 .AND. lAtuPgto .AND. AllTrim(SL1->L1_CONDPG) == "CN" .AND. SL1->L1_JUROS > 0 .AND. lMaFisFound
					    aAcrescimo[1] := (	Lj7T_TotPar(2) + LJPCCRet() + Iif( LJ220AbISS(), MaFisRet(Nil,'NF_VALISS'), 0 ) + SL1->L1_CREDITO - ;
                   							LJ7T_SubTotal(2) + aDesconto[3] - If(lHabTroco,SL1->L1_TROCO1,0) )	// Valor do acrescimo
         				aAcrescimo[2] := SL1->L1_JUROS														// Percentual do acrescimo
						LJ7T_Total( 2, LJ7T_SubTotal(2) - Lj7T_DescV(2) + aAcrescimo[1])
					EndIf
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Seleciona as NCCs a serem usadas como parte do pagamento     ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nOpc <> 2 .AND. Empty( Trim(SL1->L1_FILRES + SL1->L1_ORCRES) )
				If LjxBGetPaf()[2]
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³SIGAPHOTO - Carrega o codigo dos envelopes para ser enviado para WS da NCC para validacao de credito.³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If nModulo == 72
					    cEnvelopes := "{"
						For nCont:= 1 To Len(aColsDet)
							cEnvelopes += "'" + aColsDet[nCont][nPosEnvelo] + "',"
						Next nCont
						cEnvelopes := SUBSTR(cEnvelopes, 1, Len(cEnvelopes) -1 )
					    cEnvelopes += "}"
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//|Reinicializa as variaveis estaticas p/ rotina de NCC	³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					Frt060End()

					Frt060NCC( 	M->LQ_CLIENTE	, M->LQ_LOJA	, Nil	, Nil	,;
								@aPgtos			, Nil			, Nil	, Nil 	,;
								Nil				, cEnvelopes	,lImpOrc)

					If Frt060Ret("NCC_USADA") > 0
						Lj7AjustaTroco(Nil)
					EndIf

				Else
                    LJ7SeleNCC(nOpc)
				EndIf

                LjGrvLog(M->LQ_NUM,"NCC UTILIZADA NA VENDA",nNCCUsada)
                LjGrvLog(M->LQ_NUM,"TOTAL DA VENDA", Lj7T_Total(2))
                LjGrvLog(M->LQ_NUM,"IMPORTACAO ORCAMENTO", lImpOrc)

				If nOpc == 4 .AND. nNCCUsada >= Lj7T_Total(2)
					aPgtos := { {Ctod(Space(8)),;
								  0,;
								  Space(2),;
								  {},;
								  NIL,;
								  1,;
								  NIL,;
								  If(lVisuSint,Space(nTamL4_FORMAID),Space(01)),;
								  Space(nTamL4_CHEQUEID),;
								  0,;
								  0} } // Array para o objeto oPgtos
				EndIf
			EndIf
			
			/* Devo utilizar a condição de pagamento da SLQ porque caso
			 ocorra alteração da condição de pagamento ao alterar orçamento, 
			 o L1_CONDPG esta diferente LQ_CONDPG*/
			If nNCCUsada <> 0 .And. nOpc <> 3 .And. !Empty( M->LQ_CONDPG )
 
					Lj7CondPg(	2 				, M->LQ_CONDPG		, Nil			, (!nNCCUsada > 0)	,;
								Nil				, Nil				, Nil			, Nil				,;
								nOpc			, lTefPendCS		, Nil			, lAltCond			,;
								@nVlrAcrsFi		, Nil				, lRegraDesc	, @nPerDesc			,;
								@cAlterCond	)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Na visualizacao, os pagamentos com NCC deverao ser exibidos em branco, assim como acontece na finalizacao de uma venda³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			ElseIf nOpc == 2 .AND. SL1->L1_CREDITO > 0 //nOpc = 2 (visualizacao) E SL1->L1_CREDITO > 0 (venda com NCC)
				If Empty(aPgtos)
					aPgtos := { {Ctod(Space(8)),0,Space(3),{},NIL,nMoedaCor,Ctod(Space(8)),If(lVisuSint,Space(nTamL4_FORMAID),Space(01)),Space(nTamL4_CHEQUEID),0} }
				EndIf

			Else
				If Len(aPgtos) == 1 .AND. aPgtos[1][1] == CtoD(Space(8)) .AND. aPgtos[1][2] == 0 .AND. Empty( aPgtos[1][3] )
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Utiliza a condicao de pagamento DEFAULT do cliente, caso esteja habilitado para usa-lo³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If SuperGetMV( "MV_CONFCLI" ) == "S"
						cCond := Posicione("SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"SA1->A1_COND")
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Se a condicao estiver vazia, utilizar a condicao DEFAULT do parametro³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If Empty(cCond) .OR. nNCCUsada > 0
						If Empty(cCondPad)
							cCond := Space(nTamCondPg)
						Else
							cCond 	:= cCondPad
							lAltCond:= .T.
							If lFtvdVer12
								nVlrAcrsFi := 0
							EndIf
						EndIf
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Atualizo campo de codigo de condicao de pagamento       ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					M->LQ_CONDPG := cCond
					If lFtvdVer12
						Lj7CondPg(	2			, cCond			, Nil  		, (!nNCCUsada > 0)	, ;
									Nil			, Nil			, Nil		, Nil				, ;
									nOpc		, lTefPendCS	, .T.		, lAltCond			, ;
									@nVlrAcrsFi	, .T. 			, lRegraDesc, @nPerDesc)
					ElseIf !lFtvdVer12
						Lj7CondPg(	2			, cCond			, Nil  		, (!nNCCUsada > 0)	, ;
									Nil			, Nil			, Nil		, Nil				, ;
									nOpc		, lTefPendCS	, .T.		, lAltCond			, ;
									@nVlrAcrsFi	, .T. 			, lRegraDesc, @nPerDesc, @cAlterCond)
					EndIf
				ElseIf nOpc <> 2
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Recalcular a condicao de pagamento na tela de pagamento qdo   ³
					//³nao for visualizacao. Chama a funcao de recalculo pq os  va-  ³
					//³lores do SL4 nao sao gravados com os descontos/acrescimos     ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					cCond := M->LQ_CONDPG
                    If !lVoltaF7 .And. (nOpc == 4 .And. !lAltaPgtos)//Inibe recalculo da condição de pagamento ao entrar para finalizar orçamento
                        lAltCond := .T.                        
                    EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Setar lAtuList para .F. para nao solicitar senha de "Alteracao³
					//³de parcelas" na finalizacao da venda (nOpc == 4)				 ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
                    If nOpc == 4
                       If !(nNCCUsada <> 0 .And. Empty(cCond)) // Quando houver Ncc com condição de pagamento em branco, sera necessario a atualização do apgtos ///
                          lAtuList  := .F.
                       EndIf
                    EndIf

					Lj7CondPg(	2			, cCond		, Nil		 , lAtuList		,;
								Nil			, Nil		, Nil		 , Nil			,;
								nOpc		, lTefPendCS, .T.		 , lAltCond		,;
								@nVlrAcrsFi , Nil		,  lRegraDesc, @nPerDesc	)

				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Modifica o Action dos botoes das formas de pagamento para nao³
			//³ permitir nova selecao. A forma de pagamento para Lay-Away eh ³
			//³ NF.                                                          ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
            If (cPaisLoc $ "EUA|POR" .OR. (cPaisLoc$"MEX|COL")) .AND. lLayAway
               		bBloco := &("{ || Aviso( '" + STR0001 + "', '" + STR0090 + STR0091 + "',{'" + STR0003 + "'} ) }" )	// "Como se trata de finalizacao de Lay-Away nao e possivel selecionar outra forma de pagamento."
               For nX := 1 to Len(aLayPgtos)
                  aLayPgtos[nX][3]:bAction := bBloco
               Next nX
               Lj7CondPg(1,"NF")
            EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Prepara a tela e a toolbar para a definicao dos pagamentos 	 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7PrepTV( .T., oEncVA )

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ajusta o titulo do TOTAL da venda / mercadorias              ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			LJ7T_Total( 1, STR0008 ) // "Total da Venda"

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ajusta a variavel na tela do Troco                           ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			lCalcFrete := .T.
			/*Seta a Variável lCalcFrete para .F., caso seja NCC já está acrescido de frete neste ponto*/
			If nNCCUsada > 0
				lCalcFrete := .F.
			EndIf
			Lj7AjustaTroco(Nil)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ajusta os valores de PIS/COFINS caso Haja                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7PisCof()
	 	Else
	 		If !lAutoExB
				MsgStop(STR0009) //"Não é possível finalizar a venda pois ainda não foi vendido nenhum produto."
			Else
				ConOut(STR0009) //"Não é possível finalizar a venda pois ainda não foi vendido nenhum produto."
			EndIf
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de entrada incluindo para atender a BOPS que solicita o zeramento            ³
//³das formas de pagamento no momento em que entra na tela de Definição de Pagamentos.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLj7031 .AND. !lFtvdVer12
	LjGrvLog( NIL, " Antes da Execução do P.E. LJ7031", { lCria, lPanVA3 })
	ExecBlock( "LJ7031",.F.,.F., { lCria, lPanVA3 } )
	LjGrvLog( NIL, " Depois da Execução do P.E. LJ7031", { lCria, lPanVA3 })
EndIf

If lFTVD7031 .AND. lFtvdVer12
	LjGrvLog( NIL, " Antes da Execução do P.E. FTVD7031", { lCria, lPanVA3 })
	ExecBlock( "FTVD7031",.F.,.F., { lCria, lPanVA3 } )
	LjGrvLog( NIL, " Depois da Execução do P.E. FTVD7031", { lCria, lPanVA3 })
EndIf

Return .T.

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Programa  ³Lj7DetItem³Autor  ³ Vendas Clientes    ³ Data ³  15/10/2002 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Desc.     ³ Faz o detalhamento dos itens da venda                      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ LOJA701 - BTNBMP de Detalhe do Item.                       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpN1 - Numero da operacao do sistema(aRotina)             ³±±
±±³          ³ ExpL2 - Indica se possui TEF Pendente CLISITEF             ³±±
±±³          ³ ExpA3 - Array com transacao TEF que foi aprovada           ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7DetItem(nOpc, lTefPendCS, aTefBKPCS)
Local aArea      := GetArea()          	 													// Area atual do sistema
Local oBtOk																					// Botao Ok
Local oBtSair          					 													// Objetos da Dialog de Detalhes do Item
Local nPosProd	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local aPos       := {56,6,110,310}      													// Coordenadas da Enchoice
Local aBackGets  := aClone(aGets)       													// Backup do aGets da tela principal
Local aBackTela  := aClone(aTela)       													// Backup do aTela da tela principal
Local aCpoList   := {}                  													// Campos da ListBox
Local oDlgDetIt																				// Objeto deleta item
Local cLine      := ""                  													// String que guarda a codeblock das colunas da listbox
Local aCpoEnch   := {}                  													// Campos da Enchoice
Local oEnchDetIt                        													// Objetos da Enchoice
Local nX         := 0                   													// Variavel Auxiliar
Local nLenHDet   := 0                   													// Qtde. de campos da Array
Local lConfirma  := .F.                 													// Var. de confirmação
Local nPosDtTes	 := 0                   													// Posicao do Codigo do TES
Local cTesOri    := 0                   													// Tes Original
Local xCampo																				// Campos
Local nPos																					// Posicao
Local nVlrItem		:= 0 																	// Variavel utilizada para recalculo do valor da venda no caso de alteracao do TES
Local nVlrTotal		:= 0 																	// Variavel utilizada para recalculo do valor da venda no caso de alteracao do TES
Local lVassConc	 	:= LjVassConc()															//Indica se o cliente utiliza a Vda Assistida Concomitante
Local lCAT83 		:= SLR->(ColumnPos("LR_CODLAN")) > 0 .AND. ExistFunc("FISA023").AND. SuperGetMV("MV_CAT8309",,.F.) // Verifica CAT/83
Local cTesAnt		:= ""																	// Carrega a TES anterior
Local oPanelCab																				// Objeto do tipo tPanel posicionado no cabecalho da tela
Local oPanelCen																				// Objeto do tipo tPanel posicionado no centro da tela
Local oPanelRod                                                                             // Objeto do tipo tPanel posicionado no rodape da tela
Local xRet 			:= {}                                                                   // Retorno do ponto de entrada LJ7005
Local nCont         := 0 																	// Contador de FOR
Local lAutoExB 		:= IsBlind()															// Verifica se a rotina sera executada via execauto ou nao
Local cNomeCpo   	:= ""                  													// Campos que serao filtrados para Enchoice
Local lMVLJPDVPA 	:= LjxBGetPaf()[2] 					//Indica se é pdv
Local nPosNSerie 	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_NSERIE"})				// Posicao do campo Numero de Serie
Local nPosClasFis 	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_CLASFIS"})			// Classificação Fiscal do produto
Local nPosNLote  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE"})			// Posicao do Sub Lote
Local nPosLoteCTL	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL"})			// Posicao do Lote
Local nPosPRedIc	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PREDIC"}) 			// %Redução da Base do ICMS
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ As variaveis aDadList e oListDetIt foram alteradas suas visibilidades	|
//³ para private para serem visiveis na funcao Lj7AltCF, que sera usada     |
//³ no valid do campo LR_TES                                                |
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private aDadList   := {}        // Dados do ListBox
Private oListDetIt  		   	// Objetos da ListBox com os Detalhes do Item

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inicializacao das variaveis                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nPosProd := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Variavel Private utilizada na consulta "SB8" do SXB.						³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Private nPosCProd := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]

Default lTefPendCS := .F.
Default aTefBKPCS  := {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita as teclas de atalho                                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7SetKeys(.F.)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Consistencia do produto.                                   				³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If n == 0 .OR. aTail(aCols[n]) .OR. Empty(aCols[n][nPosProd])
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Mostra a mensagem de erro e habilita as teclas antes de retornar         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lAutoExB
		MsgStop(STR0010) //"Selecione um produto válido!"
	Else
		ConOut(STR0010) //"Selecione um produto válido!"
	EndIf
	Lj7SetKeys(.T.)
	Return Nil
EndIf

nLenHDet  := Len( aHeaderDet )      // Qtde. de campos da Array
nPosDtTes := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})	   	// Posicao do Codigo do TES
cTesOri   := aColsDet[n][nPosDtTes]	// Tes Original

//*Campos a serem visualizados na Enchoice.*/
aCpoEnch := {"LR_TES", "LR_NLOTE", "LR_LOTECTL", "LR_LOCAL", "LR_NSERIE", "LR_DTVALID"}

If !__lPyme .OR. (ExistFunc("Lj7EndSer3") .AND. Lj7EndSer3())
	aaDD( aCpoEnch, "LR_LOCALIZ")
EndIf

If lCAT83
	aAdd( aCpoEnch, "LR_CODLAN" )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de Entrada para alterar o aCpoEnch  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("LJ7005") .AND. !lFtvdVer12
	LjGrvLog(Nil,"Antes da Execução do Ponto de Entrada LJ7005")
	xRet := ExecBlock("LJ7005",.F.,.F.)
	LjGrvLog(Nil,"Depois da execução do Ponto de Entrada LJ7005", xRet)
EndIf

If ExistBlock("FTVD7005") .AND. lFtvdVer12
	LjGrvLog(Nil,"Antes da execução do Ponto de Entrada FTVD7005")
	xRet := ExecBlock("FTVD7005",.F.,.F.)
	LjGrvLog(Nil,"Depois da execução do Ponto de Entrada FTVD7005", xRet)
EndIf

If ValType(xRet) == "A" .And. (Len(xRet) > 0)
	For nCont := 1 to Len(xRet)
		aAdd( aCpoEnch, xRet[nCont])
	Next nCont

	If Empty( aCpoEnch )
		If Type("lAutoExec") <> "L" .OR. !lAutoExec
			Aviso( STR0011 , STR0012 + " ou FTVD7005" , {STR0013} ) //"Inconsistência"###"Verifique o retorno do ponto de entrada LJ7005."###"Ok"
		Else
			ConOut(STR0012 + " ou FTVD7005")
		EndIf
		
		LjGrvLog( NIL, STR0012 + " ou FTVD7005" )
		
		Return Nil
	EndIf 
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faco o posicionamento do arquivo de produtos³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea( "SB1" )
SB1->(DbSetOrder( 1 ))
SB1->(DbSeek( xFilial( "SB1" ) + aCols[n][nPosProd] ))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faco a limpeza das var. abaixo para que SB8" do SXB.						³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aTela := Nil
aGets := Nil

aEval( aHeaderDet,{|ExpA1|AAdd(aCpoList,ExpA1[1]) } )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Colunas da ListBox.                                        				³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cLine := "{|| {"

For nX := 1 To nLenHDet
	cLine += "aDadList[oListDetIt:nAt,"+AllTrim(Str(nX))+"]"+If(nX < nLenHDet,",","")
Next nX

cLine += "}}"

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Carrego variaveis de memoria do arquivo SLR                				³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 to Len( aCpoEnch )
	//Cria variaveis de memoria por _SetOwnerPrvt
	_SetOwnerPrvt(Trim(aCpoEnch[nX]),aColsDet[n][aScan(aHeaderDet,{ |ExpA1| AllTrim( ExpA1[2] ) == aCpoEnch[nX] })])

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Carrega a TES para verificar se teve alteração							³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If aCpoEnch[nX] == "LR_TES"
		cTesAnt := M->&( aCpoEnch[nX] )
	EndIf
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Carrego a Aliquota do produto cadastrado no lote                         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7RetClasFis(Nil,Nil,aColsDet[n][nPosNLote], aColsDet[n][nPosLoteCTL], n)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Carrego o item selecionado no aCols atual para o Array da ListBox        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
AAdd(aDadList,Array( nLenHDet ) )

For nX := 1 To nLenHDet
	aDadList[1][nX] := aColsDet[n][nX]
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Layout da Tela de Detalhes.                                				³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DEFINE MSDIALOG oDlgDetIt TITLE STR0014 FROM 10.5,12 to 280,640 OF oDlgDetIt PIXEL //"Detalhes do Item"

/*Painel Cabecalho*/
oPanelCab:= tPanel():New(0,0,"",oDlgDetIt,,,,,,,60)
oPanelCab:Align:= CONTROL_ALIGN_TOP

oListDetIt := TWBrowse():New( 0.2,0.2 ,312, 48,,aCpoList,,oPanelCab)

oListDetIt:SetArray( aDadList )
oListDetIt:bLine := &cLine


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Painel Central³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
oPanelCen:= tPanel():New(0,0,"",oDlgDetIt,,,,,,,)
oPanelCen:Align:= CONTROL_ALIGN_ALLCLIENT

oEnchDetIt:= MsMGet():New("SLR",0,3,,,,aCpoEnch,,,,,,,oPanelCen,,.T.)
oEnchDetIt:oBox:Align := CONTROL_ALIGN_ALLCLIENT

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Painel Rodape ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
oPanelRod:= tPanel():New(0,0,"",oDlgDetIt,,,,,,,20)
oPanelRod:Align:= CONTROL_ALIGN_BOTTOM

DEFINE SBUTTON oBtOk FROM 5,250 TYPE 1 ENABLE OF oPanelRod ACTION ( lConfirma := .T.,oDlgDetIt:End() )
DEFINE SBUTTON oBtSair FROM 5,283 TYPE 2 ENABLE OF oPanelRod ACTION ( lConfirma := .F.,oDlgDetIt:End() )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Valida se a Venda Assitida estah configurada para vendas concomitante³
//³ Se o produto jah foi impresso no ECF, a campo da TES nao pode ser    ³
//³ alterado, assim, trava ele na enchoice.                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lVAssConc
	If !Empty( aCols[n][nPosProd] )

		If LjNfPafEcf(SM0->M0_CGC) .And. lMVLJPDVPA
			oEnchDetIt:oBox:lReadOnly := .T.
		Else
		For nX := 1 To Len(oEnchDetIt:AENTRYCTRLS)
			If "M->LR_TES" $ oEnchDetIt:AENTRYCTRLS[nX]:CREADVAR
				oEnchDetIt:AENTRYCTRLS[nX]:LREADONLY := .T.  	// Marca como somente leitura
				oEnchDetIt:AENTRYCTRLS[nX]:LACTIVE 	 := .F.     // Marca como disable
			EndIf
		Next
	EndIf
EndIf
EndIf

ACTIVATE MSDIALOG oDlgDetIt CENTERED ON INIT ( oEnchDetIt:SetFocus() )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Confirmacao da tela de Detalhes.                           				³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lConfirma
	For nX := 1 to Len( aCpoEnch )
		nPos := aScan(aHeaderDet,{ |ExpA1| AllTrim( ExpA1[2] ) == aCpoEnch[nX] })
		xCampo := M->&( aCpoEnch[nX] )
  		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se houve alguma alteração nas informacoes ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If aColsDet[n][nPos] <> xCampo .OR. (aCpoEnch[nX] == "LR_TES" .AND. cTesAnt <> xCampo)
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ao alterar a TES, deve-se atualizar tambem o CFO e recalcular os     ³
			//³ valores da venda, pois pode haver cálculo de substituicao tributária ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aCpoEnch[nX] == "LR_TES"
				Lj7AltTes( xCampo, @lTefPendCS, @aTefBKPCS )
			EndIf

			//Atualiza o campo LR_NSERIE referente ao item da venda
			If nPosNSerie > 0 .And. aCpoEnch[nX] == "LR_NSERIE"
				aCols[n][aPosCpo[nPosNSerie][2]] := xCampo
			EndIf

			aColsDet[n][nPos] := xCampo
		EndIf
	Next nX

	If nPosClasFis > 0
		aCols[n][aPosCpo[nPosClasFis][2]] := iIf(ExistFunc("Lj7RetClasFis"), Lj7RetClasFis(/*cProd*/,/*cTes*/,aColsDet[n][nPosNLote], aColsDet[n][nPosLoteCTL],/*nItens*/n), Space(TamSx3("LR_CLASFIS")[1]))
	EndIf

	If nPosPRedIc > 0 .And. n > 0 .And. MaFisFound("NF") .And. MaFisFound("IT",n)
		aCols[n][aPosCpo[nPosPRedIc][2]]  :=  MaFisRet(n,"IT_PREDIC")// %Redução da Base do ICMS
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Recalcula os impostos variaveis...                                              ³
	//³Valoriza os campos de impostos no aColsDet e atualiza interface com o usuario...³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc <> "BRA" .AND. cTesOri <> aColsDet[n][nPosDtTes]
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³BOPS 111545/109909 - Envia cTesOri como parametro para   ³
		//³a função LJ7RECALIMP, para recalculo correto dos impostos³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7RecalImp(n,2,"IT_TES",Nil,cTesOri)
	EndIf
EndIf

aGets := aClone(aBackGets)
aTela := aClone(aBackTela)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Recuperando area do sistema                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
RestArea(aArea)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Habilita as teclas de atalho                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7SetKeys(.T.)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7Serial ºAutor  ³ Vendas Clientes    º Data ³  16/10/2002 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao que faz a validacao do Serial digitado              º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpL1 - Indica que a chamada foi a partir da finalizacao   º±±
±±º          ³         da venda atual.                                    º±±
±±º          ³         .T. - Indica que foi chamado no final da venda.    º±±
±±º          ³         .F. - Indica que foi chamado de qualquer ponto     º±±
±±º          ³               do programa.                                 º±±
±±º          ³ ExpN2 - Posicao do Produto no aCols que esta sendo validadoº±±
±±º          ³         (para o caso do 1 parametro estiver .T.            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso		 ³ LOJA701 													  º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Serial(lFinalVend, nLinProd)
Local cProduto   	:= ""                                										// Codigo do Produto
Local cTES       	:= ""                                										// Codigo do Tes
Local cLocal     	:= ""                          										    	// Armazem padrao
Local cNSerie    	:= ""							 										    // Numero de Serie
Local cLoteCtl   	:= ""								  										// Numero do Lote
Local cNLote     	:= ""                                										// Numero do Sub-Lote
Local cLocaliza  	:= ""                                										// Codigo da Localizacao
Local nQtdVen    	:= ""                                										// Qtde de itens vendidos
Local nX         	:= 0 								  										// Variavel Auxiliar
Local lRet       	:= .T.								  										// Retorno da Funcao
Local nPosQuant	 	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]		// Posicao da Quantidade
Local nLinSerie  	:= 0								  										// Numero de linha do acols para validar o numero de serie
Local nPosProd   	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})          	// Posicao do codigo do produto
Local nPosTes	 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})		        	// Posicao do Codigo do TES
Local nPosLocal  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCAL" })		    	// Posicao do local (armazem)
Local nPosNSerie 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NSERIE" })	        	// Posicao do Numero de serie
Local nPosLoteCTL	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL" })			// Posicao do Lote
Local nPosNLote  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE" })				// Posicao do Sub Lote
Local nPosLocaliz	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCALIZ"})				// Posicao do Localizacao
Local lLJ7055		:= ExistBlock("LJ7055")														// Bloco de código para evitar a validação do número de série
Local lRetLJ7055	:= .F.
Local lAutoExB		:= IsBlind()	   															// Verifica se a rotina sera executada via execauto ou nao
Local lFTVD7055		:= ExistBlock("FTVD7055")													// Bloco de código para evitar a validação do número de série
Local lRetFTVD7055	:= .F.
Local cGarant		:= ""																		// Produto Garantia
Local nPosGarant	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_GARANT"})					// Posição do Produto Garantia Estendida
Local lRastro 		:= .F.
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local nPosDescri	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESCRI"})][2]		// Posicao da Descricao do produto
Local cDescri		:= ""
Local nPosReserva	:=  Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_RESERVA"})			// Posição da Reserva do produto
Local lTemReserva	:= .F.																		// Variável para definir se existe reserva do produto 
Local lWmsNew		:= SuperGetMv("MV_WMSNEW",.F.,.F.)											// Parâmetro novo WMS
Local oEstEnder		:= nil																		//Para Consulta de Estoque de Endereçamento na nova Integração SIGAWMS

Default lFinalVend 	:= .F.
Default nLinProd	:= n

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Executa o bloco de código que pode cancelar a validação³
//³do número de série do produto.                         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLJ7055 .AND. !lFtvdVer12
	lRetLJ7055 := ExecBlock("LJ7055")
	If !lRetLJ7055
		Return .T.
	EndIf
EndIf

If lFTVD7055 .AND. lFtvdVer12
	lRetFTVD7055 := ExecBlock("FTVD7055")
	If !lRetFTVD7055
		Return .T.
	EndIf
EndIf

DbSelectArea("SBF")
SBF-> ( DbSetOrder(3) )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se foi chamado do LR_NSERIE e atualiza o campo lote se o mesmo ³
//³ ainda nao foi informado.                                                ³
//³ Antes posiciona no registro correto da tabela SBF                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If "LR_NSERIE" $ ReadVar() .AND. !Empty(&(ReadVar()))
	SBF-> ( DbSeek(xFilial( "SBF" ) + &(ReadVar())) )
	M->LR_LOTECTL 	:= SBF->BF_LOTECTL
	M->LR_NLOTE		:= SBF->BF_NUMLOTE
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Executo a atualizacao das variaveis necessarias para a finalizacao da   ³
//³ venda ou para validacao do campo na Enchoice de Detalhes do Item.       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If lFinalVend .Or. lAutoExB
	cProduto   := aColsDet[nLinProd][aPosCpoDet[nPosProd,2]]
	cDescri    := aCols[nLinProd][nPosDescri]	
	nQtdVen    := aCols[nLinProd][nPosQuant]
	lTemReserva:= iIf(!Empty(Alltrim(aColsDet[nLinProd][aPosCpoDet[nPosReserva,2]])),.T.,.F.)
						
	cTES       := aColsDet[nLinProd][aPosCpoDet[nPosTes][2]]
	cLocal     := aColsDet[nLinProd][aPosCpoDet[nPosLocal][2]]
	cNSerie    := aColsDet[nLinProd][aPosCpoDet[nPosNSerie][2]]
	cLoteCtl   := aColsDet[nLinProd][aPosCpoDet[nPosLoteCTL][2]]
	cNLote     := aColsDet[nLinProd][aPosCpoDet[nPosNLote][2]]
	cLocaliza  := aColsDet[nLinProd][aPosCpoDet[nPosLocaliz][2]]
	
	//Verifica se o item possui garantia estendida associada
	If nPosGarant > 0
		cGarant    := aCols[nLinProd][nPosGarant]
	EndIf

Else
	cProduto   := aColsDet[n][aPosCpoDet[nPosProd,2]]
	cDescri    := aCols[n][nPosDescri]	
	nQtdVen    := aCols[n][nPosQuant]
	lTemReserva:= iIf(!Empty(Alltrim(aColsDet[n][aPosCpoDet[nPosReserva,2]])),.T.,.F.)

	cTES       	:= aColsDet[nLinProd][aPosCpoDet[nPosTes][2]]
	cLocal     := M->LR_LOCAL
	cNSerie    := M->LR_NSERIE

    If !__lPyme .OR. (ExistFunc("Lj7EndSer3") .AND. Lj7EndSer3())
    	cLoteCtl   := M->LR_LOTECTL
	    cNLote     := M->LR_NLOTE
		cLocaliza  := M->LR_LOCALIZ
    Else
    	cLoteCtl   := Space(Len(SLR->LR_LOTECTL))
	    cNLote     := Space(Len(SLR->LR_NLOTE))
	    cLocaliza  := Space(Len(SLR->LR_LOCALIZ))
    EndIf

EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Posiciona o produto dentro do SB1³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
SB1->(DbSetOrder(1))
SB1->(DbSeek(xFilial("SB1") + cProduto))

SF4->(DbSetOrder(1))
SF4->(DbSeek(xFilial("SF4") + cTes))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o produto possui controle de rastro.                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ\ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !(LjxBGetPaf()[2])
	lRastro := Rastro(cProduto) 
	If lRastro
		If (SB1->B1_RASTRO == "L") .AND. Empty(cLoteCtl) .AND. (SF4->F4_ESTOQUE == "S")
			If !lAutoExB
				Aviso( STR0015, STR0162 + cProduto, {STR0013} ) //"Atenção"###" "Verifique o campo Lote presente nos Detalhes do Item <F8> para o produto " "###"Ok"
			Else
				ConOut(STR0162 + cProduto)
			EndIf
			lRet := .F.

		ElseIf (SB1->B1_RASTRO == "S")  .AND. (Empty(cNLote) .OR. Empty(cLoteCtl)) .AND. (SF4->F4_ESTOQUE == "S")
			If !lAutoExB
				Aviso( STR0015, STR0163 + cProduto, {STR0013} ) //"Atenção"### "Verifique os campos Lote e Sub-Lote presente nos Detalhes do Item <F8> para o produto " ###"Ok"
			Else
				ConOut(STR0163 + cProduto)
			EndIf
			lRet := .F.
		EndIf
	EndIf
ElseIf lFtvdVer12
	lRastro :=  Rastro(cProduto)
	
	If lRastro
		If (SB1->B1_RASTRO == "L") .AND. Empty(cLoteCtl) .AND. (SF4->F4_ESTOQUE == "S")
			If Type("lAutoExec") <> "L" .OR. !lAutoExec
				Aviso( STR0015, STR0162 + cProduto, {STR0013} ) //"Atenção"###" "Checar o campo Lote para o produto " "###"Ok"
			Else
				ConOut(STR0162 + cProduto)
			EndIf
			lRet := .F.
		ElseIf (SB1->B1_RASTRO == "S")  .AND. (Empty(cNLote) .OR. Empty(cLoteCtl)) .AND. (SF4->F4_ESTOQUE == "S")
			If Type("lAutoExec") <> "L" .OR. !lAutoExec
				Aviso( STR0015, STR0163 + cProduto, {STR0013} ) //"Atenção"### "Checar os campos Lote e Sub-Lote para o produto "###"Ok"
			Else
				ConOut(STR0163 + cProduto)
			EndIf
			lRet := .F.
		EndIf
	EndIf
EndIf

If lRet
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se o item selecionado esta excluido.                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If aTail( aCols[nLinProd] )
		lRet := .F.
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se o produto usa localizacao fisica.                       ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ElseIf Localiza( cProduto ) .AND. Empty(cLocaliza) .AND. (SF4->F4_ESTOQUE == "S") .AND. lFinalVend;
				.AND. !(IntWms(cProduto))
		If !lAutoExB
			Aviso( STR0015 , STR0164 + cProduto, {STR0013} ) //"Atenção"### "Verifique o campo Endereço presente nos Detalhes do Item <F8> para o produto " "###"Ok"
		Else
			ConOut(STR0164 + cProduto)
		EndIf
		lRet := .F.

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se foi informado o Armazem.                                ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ElseIf Empty( cLocal ) .AND. lFinalVend
		If !lAutoExB
			Aviso( STR0015 , STR0018 , {STR0013} ) //"Atenção"###"Digitação do Armazém é obrigatória !"###"Ok"
		Else
			ConOut(STR0018)
		EndIf
		lRet := .F.

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se a tes selecionada permite baixa no estoque.             ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ElseIf lFinalVend .And. IIF(ExistFunc("Lj7ValTES"), !Lj7ValTES(cTes), !A410ValTES(cTes))
		lRet := .F.

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se a quantidade digitada na venda corresponde a 1 item.    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ElseIf !Empty(cNSerie) .AND. nQtdVen <> 1 .AND. lFinalVend .And. lRastro // Quantidade deve ser validada (1 item para cada serial)
		If !lAutoExB
			Aviso( STR0015 , STR0019 , {STR0013} ) //"Atenção"###"A Quantidade por serial deve ser igual a 1 !"###"Ok"
		Else
			ConOut(STR0019)
		EndIf
		lRet := .F.

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Caso o numero de serie estiver devidamente digitada...              ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ElseIf !Empty(cNSerie) .AND. lFinalVend .And. lRastro

		If lFinalVend					// Se for finalizacao de venda, nLinSerie sera o nLinProd, senao sera o n
			nLinSerie := nLinProd
		Else
			nLinSerie := n
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se o numero de serie foi utilizado por outros itens do mesmo porduto. ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		For nX := 1 to Len( aColsDet ) // Verifica se a serial ja foi utilizada
			If !aTail(aCols[nX]) .AND. (nX <> nLinSerie )							// Nao verifico no item atual
				If (aColsDet[nX][aPosCpoDet[nPosNSerie][2]] == cNSerie) .AND. (aColsDet[nX][nPosProd] == aColsDet[nLinSerie][nPosProd] ) // Deve validar com relacao aos outros campos
					If !lAutoExB
						Aviso( STR0015 , STR0020 , {STR0013} ) 							//"Atenção"###"Numero de Serial já foi utilizada em outro item !"###"Ok"
					Else
						ConOut(STR0020)
					EndIf
					lRet := .F.
				EndIf
			EndIf
		Next nX

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Caso o numero foi digitado, conferir se o mesmo esta cadastrado     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea( "SBF" )
		SBF->(DbSetOrder(4))
		If !SBF->(DbSeek(xFilial( "SBF" ) + cProduto + cNSerie))
			If !lAutoExB
				Aviso( STR0015 , STR0021 , {STR0013} ) //"Atenção"###"Não existe este número de serial disponível para uso !"###"Ok"
			Else
				ConOut(STR0021)
			EndIf
			lRet := .F.
		EndIf

		If lRet
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verificando a integridade das informacoes cadastradas.          ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If SBF->BF_PRODUTO     <> cProduto
				If !lAutoExB
					Aviso( STR0015 , STR0022 , {STR0013} ) //"Atenção"###"Este serial está sendo utilizado por outro produto da loja !"###"Ok"
				Else
					Conout(STR0022)
				EndIF
				lRet := .F.
			ElseIf SBF->BF_LOCAL   <> cLocal
				If !lAutoExB
					Aviso( STR0015 , STR0023 + SBF->BF_LOCAL , {STR0013} ) //"Atenção"###"Rever Localização do Produto... Local: "###"Ok"
				Else
					ConOut(STR0023 + SBF->BF_LOCAL)
				EndIf
				If lFinalVend
					lRet := .F.
				EndIf
			ElseIf SBF->BF_LOCALIZ <> clocaliza .AND. Empty(cGarant) //Nao e garantia estendida
				If !lAutoExB
					Aviso( STR0015 , STR0024+ SBF->BF_LOCALIZ , {STR0013} ) //"Atenção"###"Rever Localização do Produto... Localização: "###"Ok"
				Else
					ConOut(STR0024+ SBF->BF_LOCALIZ)
				EndIf
				If lFinalVend
					lRet := .F.
				EndIf
			ElseIf SBF->BF_NUMLOTE <> cNLote .AND. Rastro(cProduto, 'S')
				If !lAutoExB
					Aviso( STR0015 , STR0025 + SBF->BF_NUMLOTE, {STR0013} ) //"Atenção"###"Rever Localização do Produto... Lote: "###"Ok"
				Else
					ConOut(STR0025 + SBF->BF_NUMLOTE)
				EndIf
				If lFinalVend
					lRet := .F.
				EndIf
			ElseIf SBF->BF_LOTECTL <> cLotectl
				If !lAutoExB
					Aviso( STR0015 , STR0026 + SBF->BF_LOTECTL , {STR0013} ) //"Atenção"###"Rever Localização do Produto... Sub-Lote: "###"Ok"
				Else
					ConOut(STR0026 + SBF->BF_LOTECTL)
				EndIf
				If lFinalVend
					lRet := .F.
				EndIf
			EndIf

		EndIF
	ElseIf !Empty(cLocaliza) .AND. Empty(cNSerie) .AND. !lWmsNew .AND. ;
				nQtdVen > SaldoSBF(cLocal,cLocaliza,cProduto,cNSerie,NIL,NIL,  IIf((lTemReserva .AND. lFinalVend),.T.,.F.),NIL)	//Pode existir produto com controle de endereco sem serial informado na SBF	 			
		If !lAutoExB
			Aviso(STR0161,STR0211 + AllTrim(cLocaliza) + STR0212 + AllTrim(cDescri),{STR0003},2)	// "Endereço" ## "A quantidade disponível no endereço:"  ## " não é suficiente para suprir a quantidade informada no Produto:" 
		Else
			ConOut(STR0211 + AllTrim(cLocaliza) + STR0212 + AllTrim(cDescri) )
		EndIf		
		lRet := .F.
	ElseIf !Empty(cLocaliza) .AND. Empty(cNSerie) .AND. lWmsNew	//Somente Integração Sigaloja x novo Sigawms habilitado
		If oEstEnder = nil
			oEstEnder 	:= WMSDTCEstoqueEndereco():New()
		EndIf

		oEstEnder:ClearData()
		oEstEnder:oEndereco:SetArmazem(cLocal)
		oEstEnder:oEndereco:SetEnder(cLocaliza)
		oEstEnder:oProdLote:SetArmazem(cLocal)   // Armazem
		oEstEnder:oProdLote:SetPrdOri(cProduto)  // Produto Origem - Componente
		oEstEnder:oProdLote:SetProduto(cProduto) // Produto Principal
		oEstEnder:oProdLote:SetLoteCtl(cLoteCtl) // Lote do produto principal que deverá ser o mesmo no componentes
		oEstEnder:oProdLote:SetNumLote(cNLote)   // Sub-Lote do produto principal que deverá ser o mesmo no componentes

		If nQtdVen > oEstEnder:ConsultSld(.F.,.F.)	//Pode existir produto com controle de endereco sem serial informado na D14  			
			If !lAutoExB
				Aviso(STR0161,STR0215 + STR0211 + AllTrim(cLocaliza) + STR0212 + AllTrim(cDescri),{STR0003},2)	// "Endereço" ## "Novo WMS: " ## "A quantidade disponível no endereço:"  ## " não é suficiente para suprir a quantidade informada no Produto:" 
			Else
				ConOut(STR0215 + STR0211 + AllTrim(cLocaliza) + STR0212 + AllTrim(cDescri) )	// "Novo WMS: " ## "A quantidade disponível no endereço:"  ## " não é suficiente para suprir a quantidade informada no Produto:"
			EndIf		
			lRet := .F.
		EndIf
	EndIf
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7Lote  ºAutor  ³ Vendas Clientes    º Data ³  20/10/2002 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao que faz a validacao do lote digitado nos detalhes   º±±
±±º          ³ da venda Assistida (resolucao do BOPS 109225)              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpC1 - Armazem do produto(opcional)                       º±±
±±º          ³ ExpC2 - Lote do produto(opcional)                          º±±
±±º          ³ ExpC3 - Sublote do produto(opcional)                       º±±
±±º          ³ ExpN4 - Quantidade solicitada para o produto(opcional)     º±±
±±º          ³ ExpC5 - Produto vindo da Aprovação Med. Templ.Drogaria(opc)º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Lote(cLocal	, cLoteSel	, cSubLoteSel, nQuant, cProd)

Local aArea		:= GetArea()
Local lRet			:= .T.																// Retorno da funcao, liberando ou nao o campo para edicao
Local lRetSB1		:= .T.																// Retorno da pesquisa do produto, necessaria para validar se o mesmo tem controle por lote/rastro
Local cRastro		:= SuperGetMV("MV_RASTRO")											// Verifica se a rastreabilidade esta' habilitada
Local cEstNeg  	:= SuperGetMV("MV_ESTNEG")											// Verifica se e' permitido fazer movimentacoes de estoque com saldo negativo
Local nPosProd	:= 0															 	// Guarda posicao do campo LR_PRODUTO para procura no aColsDet
Local nPosQtde	:= 0   																// Guarda posicao do campo LR_QUANT para procura no aCols
Local aAreaSB1	:= SB1->(GetArea())												// Guarda area atual do SB1
Local aAreaSB8	:= SB8->(GetArea())												// Guarda area atual do SB8
Local nQtdVda		:= 0																// Quantidade vendida, informada no aCols
Local cLote		:= Space(TamSX3("LR_LOTECTL")[1])									// Retorno para o campo Lote
Local cSubLote	:= Space(TamSX3("LR_NLOTE")[1])									// Retorno para o campo SubLote
Local dDtValid	:= ""																// Retorno para o campo SubLote
Local nSaldo		:= 0																// Data de validade do lote
Local lEmpPrev 	:= (SuperGetMV("MV_QTDPREV")== "S")								// Verifica se esta baixando empenho previsto
Local cProduto	:= ""																// Codigo do produto
Local nTamX3Prod	:= TamSX3("B8_PRODUTO")[1]											// Tamanho do campo de Codigo do produto da SB8 no SX3
Local lAutoExB	:= IsBlind()														// Verifica se a rotina sera executada via execauto ou nao

Local aSxFci		:= LjCFciParam()
Local lFciVlImpor	:= SL2->(FieldPos("L2_VLIMPOR")) > 0 .And. SLR->(FieldPos("LR_VLIMPOR")) > 0 .And. aSxFci[5] .And. aSxFci[6]
Local lFciCod		:= SL2->(FieldPos("L2_FCICOD")) > 0 .And. SLR->(FieldPos("LR_FCICOD")) > 0 .And. aSxFci[4] .And. aSxFci[8]
Local lClasFis	:= SL2->(FieldPos("L2_CLASFIS")) > 0 .And. SLR->(FieldPos("LR_CLASFIS")) > 0//Classificação Fiscal do Produto
Local nPosBIcms	:= 0
Local nPosVIcms	:= 0
Local lHeader		:= Type("aHeader") = "A"
Local lHeaderDet	:= Type("aHeaderDet") = "A"
Local lCols			:= Type("aCols") = "A" .AND. Len(aCols) > 0
Local lColsDet		:= Type("aColsDet") = "A" .AND. Len(aColsDet) > 0
Local caProd		:= ""
Local nPosReser 	:= 0 //Posição da Reserva
Local lAutResev     := .F. // Indica se a venda é originada de Integração e possui Reserva

Default nQuant			:= 1														 	// Quantidade vendida da linha atual
Default cLocal			:= M->LR_LOCAL													// Armazem (Local) em que o produto foi vendido
Default cLoteSel		:= M->LR_LOTECTL												// Lote selecionado pelo usuario
Default cSubLoteSel 	:= M->LR_NLOTE													// SubLote selecionado pelo usuario
Default cProd			:= ""															// Produto que vem fora do grid da Venda Assistida

Static _aItensLote	:= {"",{}}														// Controla a notificacao sobre a validade do lote para cada item

If lHeader
	nPosQtde	:= Ascan(aHeader,   {|x| AllTrim(Upper(x[2])) == "LR_QUANT"})
EndIf

If lHeaderDet
	nPosProd	:= Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_PRODUTO"})
	nPosBIcms	:= Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_BASEICM"})
	nPosVIcms	:= Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_VALICM"})
	nPosReser	:= Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_RESERVA"})
EndIf

If lCols
	nQuant			:= aCols[n][nPosQtde]
EndIf

If lColsDet
	caProd	:= aColsDet[n][nPosProd]
	lAutResev := M->LQ_ORIGEM =="N" .AND. !Empty(aColsDet[n][Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_RESERVA"})])
Else
	caProd	:= cProd 
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Para a versao 10, verifica se o campo existe antes³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SLR->(FieldPos( "LR_DTVALID" ) ) > 0
	dDtValid	:= Space(TamSX3("LR_DTVALID")[1])
Else
	dDtValid	:= Space(TamSX3("LQ_EMISSAO")[1])
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³A cada novo orcamento, a variavel _aItensLote sera reiniciada³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If _aItensLote[1] <> M->LQ_NUM
	_aItensLote[1] := M->LQ_NUM
	_aItensLote[2] := {}
EndIf

If Empty(cLoteSel)
	Return(lRet)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o sistema esta' configurado para controle por lote.                          ³
//³Se estiver, prossegue com as validacoes somente se for digitado alguma coisa,            ³
//³para nao ficar apresentando mensagens toda vez que o usuario passar pelo campo LR_LOTECTL³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cRastro <> "S" .AND. AllTrim(cLoteSel) <> ""
	lRet := .F.
	If !lAutoExB
		Aviso(STR0148,STR0149,{STR0003},2) //"Lote","O sistema não está configurado para controle por lote/rastro.","Ok"
	Else
		ConOut(STR0149)
		LjGrvLog("Lj7Lote", STR0149)//"O sistema não está configurado para controle por lote/rastro."
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica quantidade vendida no aCols, ja' que aColsDet nao possui quantidade. ³
//³Se o campo "Quantidade" nao existir no aCols, assume 1 como quantidade vendida³
//³(porque pelo menos 1 unidade tem que ser vendida                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet
	If nPosQtde > 0
		nQtdVda := nQuant
	Else
		nQtdVda := 1
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Procura no SB1, para verificar se o produto possui controle por lote/rastro³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. cRastro == "S" .AND. !Empty(caProd)
	DbSelectArea("SB1")
	DbSetOrder(1) // B1_FILIAL + B1_COD
	If ( DbSeek( xFilial("SB1") + caProd ) )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Se o armazem (local) nao foi alimentado pelo aColsDet, pega o local do cadastro de produtos³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If AllTrim(cLocal) == ""
			cLocal := SB1->B1_LOCPAD
		EndIf
		If SB1->B1_RASTRO == "N"
			lRetSB1 := .F.
			If !lAutoExB
				Aviso(STR0148,STR0150,{STR0003},2)//"Lote","Este produto não possui controle por lote/rastro.","Ok"
			Else
				ConOut(STR0150)
				LjGrvLog("Lj7Lote", STR0150)//"Este produto não possui controle por lote/rastro."
			EndIf
		EndIf
	Else
		lRet := .F.
		If !lAutoExB
			Aviso(STR0148,STR0151,{STR0003},2)//"Lote", "Produto não cadastrado.","Ok"
		Else
			ConOut(STR0151)
			LjGrvLog("Lj7Lote", STR0151)//"Produto não cadastrado."
		EndIf
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Valida se o lote existe, e se ha' quantidade disponivel para ser vendida,                           ³
//³observando o conteudo do parametro MV_ESTNEG (permite movimentacoes em produtos com saldo negativo0.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. lRetSB1 .AND. cRastro == "S" .AND. !Empty(caProd)
	If Empty(cSubLoteSel)
		cSubLoteSel	:= ""
	EndIf

	cProduto := SubStr(caProd + Space(nTamX3Prod), 1, nTamX3Prod)

	DbSelectArea("SB8")
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³B8_FILIAL+B8_PRODUTO+B8_LOCAL+B8_LOTECTL+B8_NUMLOTE+DTOS(B8_DTVALID)³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	SB8->( DbSetOrder(3) )	//B8_FILIAL, B8_PRODUTO, B8_LOCAL, B8_LOTECTL, B8_NUMLOTE, B8_DTVALID
	If SB8->( DbSeek(xFilial("SB8") + cProduto + cLocal + cLoteSel + cSubLoteSel) )

		nSaldo	:= SB8Saldo(NIL,NIL,NIL,NIL,NIL,lEmpPrev)

		If nSaldo < nQtdVda .and. !lAutResev
			lRet := .F.
			If !lAutoExB
				Aviso(STR0148,STR0152,{STR0003},2)//"Lote", "A quantidade disponível neste lote não é suficiente para suprir a quantidade informada.","Ok"
			Else
				ConOut(STR0152)
				LjGrvLog("Lj7Lote", STR0152)//"A quantidade disponível neste lote não é suficiente para suprir a quantidade informada."	  
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica a data de validade do produto, e apresenta uma mensagem para o usuario,         ³
		//³permitindo ou nao a escolha do produto (somente se a data de validade estiver preenchida)³
		//³Ao confirmar o lote vencido, a resposta sera armazenada para este item durante a venda.  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

		If lRet .AND. (aScan(_aItensLote[2],{|x|	(x[1] == N) .AND.;
													(x[2] == caProd)  .AND.;
													(x[3] == cLoteSel+cSubLoteSel)}) == 0) .AND. !lAutResev
			If !Empty(SB8->B8_DTVALID)
				If SB8->B8_DTVALID < dDataBase
					If lAutoExB .Or. (!lAutoExB .And. MsgYesNo(STR0153,STR0154))  //"Este produto deste lote está com a validade vencida. Continua?","Data de Validade"
						lRet := .T.
						AAdd(_aItensLote[2],{N , caProd, cLoteSel + cSubLoteSel, SB8->B8_DTVALID })
						dDtValid := SB8->B8_DTVALID
 			   			M->LR_DTVALID := dDtValid
					Else
						lRet := .F.
					EndIf
		 		Else
		   			dDtValid := SB8->B8_DTVALID
		   			M->LR_DTVALID := dDtValid
				EndIf
			Else
   				dDtValid := SB8->B8_DTVALID
   				M->LR_DTVALID := dDtValid
   			EndIf
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Guarda o sublote, para retorno ao campo "Sublote" da tela, ao final da funcao ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lRet
			cSubLote := SubStr(SB8->B8_NUMLOTE,1,Len(cSubLote))
		EndIf
						
		//Valida se houve alteracao de lote e limpa campo serial, tratamento similar ocorre na rotina LJ7Serial() quando altera o serial, atualiza o Lote/Sublote, porém, apenas com o lote não é possível definir qual serial sera vendido.
		If !Empty(M->LR_NSERIE) .AND. ((SB8->B8_LOTECTL <> SBF->BF_LOTECTL) .OR. (SB8->B8_NUMLOTE <> SBF->BF_NUMLOTE))
			M->LR_NSERIE := Space(TamSx3("L2_NSERIE")[1])
		EndIf		
	Else
		lRet := .F.
		If !lAutoExB
			Aviso(STR0148,STR0155,{STR0003},2)//"Lote", "O lote não foi informado ou não existe.","Ok"
		Else
			ConOut(STR0155)
			LjGrvLog("Lj7Lote", STR0155)//"O lote não foi informado ou não existe."
		EndIf
	EndIf
EndIf

RestArea(aAreaSB1)
RestArea(aAreaSB8)

cSubLoteSel := PadR(cSubLoteSel,TAMSX3("D5_NUMLOTE")[1])

If cRastro == "S" .And. lRet .And. lRetSB1 
	If aSxFci[1] .And. aSxFci[9] .And. (lFciVlImpor .Or. lFciCod) .And. lClasFis .AND. MaFisFound("IT", n)
		LjCRetFci(caProd, cSubLoteSel, cLoteSel,,, MaFisRet(n,"IT_CLASFIS"), n)

		If Type("aDadList") == "A" //Variaveis private criadas apeans quando clicado no botão detalhes do venda assistida.
			aDadList[1][nPosBIcms] := MaFisRet(n, "IT_BASEICM")
			aDadList[1][nPosVIcms] := MaFisRet(n, "IT_VALICM")
			oListDetIt:Refresh()
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Limpa o campo antes de retornar e deixa prosseguir, caso o sistema ou produto nao tenha controle por lote³
//³OBS.: em caso de implementacoes futuras, este tratamento deve estar sempre antes do retorno para o campo ³
//³LR_LOTECTL                                                                                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cRastro <> "S" .OR. !lRetSB1
	lRet := .T.
	M->LR_LOTECTL := cLote
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Retorna o campo "Sublote" preenchido, simulando a pesquisa padrao do SXB, caso o campo exista³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lHeaderDet .AND. Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_NLOTE"}) > 0
	M->LR_NLOTE := cSubLote
EndIf

RestArea(aArea)

Return(lRet)


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7PrepTV ³ Autor ³ Vendas Clientes      ³ Data ³ 17/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Rotina que prepara a tela de venda para a definicao dos 	  ³±±
±±³			 ³ pagamentos.												  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ void LOJA701( ExpL1, ExpO1 )                               ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpL1 -	.T. - Prepara para pagamentos (DEFAULT)           ³±±
±±³			 ³          .F. - Restaura a anterior                         ³±±
±±³			 ³ ExpO1 -  Enchoice da venda (SL1)                           ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7PrepTV( lPrepara, oEncVA )

Default lPrepara := .T.

If lPrepara
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Salva a posicao atual das funcoes (aFuncoes)				 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	LJ7F_Salva(.T.)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Muda titulo e a dica da opcao \Detalhar\Pagamento 			 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Titu(  4, STR0027 ) // "Venda"
	Lj7F_Dica(  4, STR0028 ) // "Retornar para venda"

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Desabilita no menu as opcoes padrao                          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Menu(  1, !lRecebe )	// Gravar orcamento
	Lj7F_Menu(  4, !lRecebe )	// Retornar para venda
	Lj7F_Menu(  5, .F. )		// Item
	Lj7F_Menu(  6, .F. )		// Frete
	Lj7F_Menu(  8, .F. )		// Efetuar reserva
	Lj7F_Menu(  9, .F. )		// Consultar reserva
	Lj7F_Menu( 10, .F. )		// Consultar estoque
	Lj7F_Menu( 11, .F. )		// Desconto
	Lj7F_Menu( 12, .F. )		// Tabela de precos
	Lj7F_Menu( 15, .T. )		// Financiamento

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita as opcoes de venda e Financiamento (fator)     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Menu(  2, .T. )		// Venda
	Lj7F_Menu( 14, .T. )		// Consulta Eletronica
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Restaura a posicao das funcoes (aFuncoes)					 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Salva(.F.)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Muda titulo e a dica da opcao \Detalhar\Pagamento 			 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Titu(  4, Lj7F_Titu(4) ) // "Pagamento"
	Lj7F_Dica(  4, Lj7F_Dica(4) ) // "Definir pagamento"

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita no menu as opcoes padrao                            ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Menu(  5, .T. )		// Item
	Lj7F_Menu(  6, .T. )		// Frete
	Lj7F_Menu(  8, .T. )		// Efetuar reserva
	Lj7F_Menu(  9, .T. )		// Consultar reserva
	Lj7F_Menu( 10, .T. )		// Consultar estoque
	Lj7F_Menu( 11, .T. )		// Desconto
	Lj7F_Menu( 12, .T. )		// Tabela de precos
	Lj7F_Menu( 15, .T. )		// Troca de mercadorias

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Desabilita as opcoes de venda e Financiamento (fator)   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7F_Menu(  2, .F. )		// Venda
	Lj7F_Menu( 14, .F. )		// Financiamento
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita os objetos da enchoice							 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
oEncVA:oBox:lReadOnly := lPrepara

Return .T.

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7MontPg ºAutor  ³ Vendas Clientes    º Data ³  08/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Monta o painel dos botoes com as formas de pagamento        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Void Lj7MontPg( ExpO1, ExpO2, ExpA1 )                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpO1 - Objeto Panel que deverah conter os botoes com as    º±±
±±º          ³        formas de pagamento                                 º±±
±±º          ³ExpO2 - Objeto Panel que deverah conter as informacoes da   º±±
±±º          ³        Condicao Negociada                                  º±±
±±º          ³ExpA3 - Array com a posicao relativa do Panel               º±±
±±º          ³ExpN4 - Numero da operacao do sistema                       º±±
±±º          ³ExpA5 - Array com as formas de pagto. para finalizacao de   º±±
±±º          ³        Lay-Away                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LJ7DefPag                                                   º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7MontPg( oPanVAPg	, oPanCondNeg	, aPosObjPg, nOpc		,;
	 				aLayPgtos 	, lTefPendCS	, aTefBKPCS, cAlterCond	,;
	 				nVlrAcrsFi  , aDadosCNeg	)

Local aArea 		:= GetArea()
Local aObjButtons 	:= {}																					// Array contendo o objeto dos botoes
Local aInfButtons 	:= {}																					// Array contendo informações dos botoes
Local aPosObjBut	:= {}
Local aObjCondNeg 	:= {}
Local aInfCondNeg 	:= {}
Local aPosCondNeg	:= {}
Local aTipoJuros 	:= { STR0029, STR0030, STR0031 }														// Variavel para o combo box da condicao negociada //"1 - Simples"###"2 - Composto"###"3 - Tabela Price"
Local lCalcFin      := (SuperGetMv("MV_CALCFIN",,"M")== "M")
Local aTecAtalho    := {}																					// Array contendo teclas de atalho
Local aAreaSX3 		:= {}																					// Array contendo a area do SX3
Local oIntDVenc
Local nItensLin		:= 0																					// Variavel que recebe item da linha
Local nLinha 		:= 0																					// Variavel que recebe numero da linha
Local nX, nY		:= 0																					// Variavel contador
Local nObjetos		:= 7																					// Variavel que recebe numero de objetos
Local cMvSimb1		:= SuperGetMV("MV_SIMB1")																// Variavel que recebe o parametro MV_SIMB1
Local bBloco        := {|| NIL }
Local aRet
Local lLj7010		:= ExistBlock("LJ7010")																	// Variavel logica para checar Ponto de entrada
Local lLj7020		:= ExistBlock("LJ7020")																	// Variavel logica para checar Ponto de entrada
Local lAddBtn
Local lHideBtn		:= .F.
Local lDisableBt	:= .F.
Local lCriaBt       := .T. 																					// Variavel para utiliacao de Templates
Local nTamAE_COD    := TamSX3("AE_COD")[1]    																// Tamanho do campo AE_COD
Local nTamE4_COD    := TamSX3('E4_CODIGO')[1] 																// Tamanho do campo E4_CODIGO
Local nTamLQ_CON    := TamSX3("LQ_CONDPG")[1] 																// Tamanho do campo LQ_CONDPG
Local nPosAE_MSBL	:= SAE->(ColumnPos( "AE_MSBLQL" ) )														// Verifica se existe o campo AE_MSBLQL
Local lAtivaMn		:= SuperGetMV("MV_LJMULTN", , .F.) 														// Ativa cenario de Vendas
Local lAutoExB 		:= IsBlind()																			// Verifica se a rotina sera executada via execauto ou nao
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - Cartao Fidelidade³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lLjcFid 		:= SuperGetMv("MV_LJCFID",,.F.) .AND. CrdxInt() 								//Indica se a recarga de cartao fidelidade esta ativa
Local lFTVD7010		:= ExistBlock("FTVD7010")																	// Variavel logica para checar Ponto de entrada
Local lFTVD7020		:= ExistBlock("FTVD7020")																	// Variavel logica para checar Ponto de entrada
Local cMNFormPg  	:= SuperGetMV("MV_LJMNFPG",,'') 														// Parametro que suprime as condicoes de pagamento
Local lLJAltPG   	:= SuperGetMV("MV_LJALTPG",,.T.)														// Permite a alteracao da condicao de pagamento pelo Get na parte inferior
Local lLjVldPbm		:= ExistFunc("LjVldPbm") .AND. !(ExistFunc("T_DroPbmDe") .AND. T_DroPbmDe())
Local lAltaPgtos	:= SuperGetMV( "MV_LJALTAP",,.F.) //Permite alteração do aPgtos apos escolha da condição de pagameto na finalização da venda
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default nVlrAcrsFi 	:= 0
Default aDadosCNeg	:= {}

Static aFormPgtos	:= {}
Static cVldLQCondPg	:= ".T."
Static cWhenQCondPg	:= ".T."

// Variavel para os objetos da tela da condicao negociada
aDadosCNeg := { {aTipoJuros[1], dDatabase, 0, M->LQ_JUROS, 1, 30, lCalcFin, .F.}, Array(8) }

If Empty(M->LQ_CONDPG) .OR. M->LQ_CONDPG == "CN "
	M->LQ_CONDPG := Space(nTamAE_COD)
Else
	cDescCondPg := Posicione("SE4",1,xFilial("SE4")+M->LQ_CONDPG,"SE4->E4_DESCRI")
EndIf
If Empty(M->LQ_TIPOJUR)
	M->LQ_TIPOJUR		:= 0
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checa o X3_VLDUSER do campo LQ_CONDPG                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("Sx3")
aAreaSX3 := GetArea()
SX3->(DbSetOrder(2))
If SX3->(DbSeek( "LQ_CONDPG" ))
	If !Empty(SX3->X3_VLDUSER)
		cVldLQCondPg := AllTrim(SX3->X3_VLDUSER)
	Else
		cVldLQCondPg := ".T."
	EndIf
	If !Empty(SX3->X3_WHEN)
		cWhenQCondPg := AllTrim(SX3->X3_WHEN)
	Else
		cWhenQCondPg := ".T."
	EndIf
EndIf
RestArea( aAreaSX3 )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Prepara o Campo para a Condicao de Pagamento (via SE4)       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
@ aPosObjPg[1,3]-aPosObjPg[1,1]-10, 002 SAY STR0032 PIXEL OF oPanVAPg  //"Condição de Pgto"

@ aPosObjPg[1,3]-aPosObjPg[1,1]-12, 060 MSGET oCondPg 	VAR		M->LQ_CONDPG F3 Posicione("SX3",2,"LQ_CONDPG ","X3_F3") ;
														VALID	(Empty(M->LQ_CONDPG) .OR. ExistCpo("SE4",M->LQ_CONDPG)) .AND.;
																&(cVldLQCondPg)	.AND.;
																(LJ7VldCond(M->LQ_CONDPG, @cDescCondPg, @oDescCondPg, @oPgtos, @cAlterCond, nOpc, @nVlrAcrsFi)) ;
														WHEN 	IIf ( lLJAltPG,;
																	( nOpc <> 2 .AND. !lLayAway ) .AND. !lTefPendCS .AND. &(cWhenQCondPg),;
																	.F.);																
														PIXEL OF oPanVAPg
oCondPg:bGotFocus := {|| oCondPg:bGotFocus := NIL}
oCondPg:SetFocus()
//³Atualiza o oPgto com a condicao selecionada assim que sair do oCondPgto³
oCondPg:bLostFocus := { ||; 
						If(!Empty( M->LQ_CONDPG ) .And. ExistCpo("SE4",M->LQ_CONDPG), ;
						LJ7VldCond(M->LQ_CONDPG, @cDescCondPg, @oDescCondPg, @oPgtos, @cAlterCond, nOpc, @nVlrAcrsFi, ;
						IIF(!lAltaPgtos, .T., ValType(cCondSe4) == "C" .And. (!Empty(Alltrim(cCondSE4)) .Or. cCondSE4 <> M->LQ_CONDPG)) ), .T. ) }
//Validacao inclusa para verificar quando alteracao de orçamento, que foi atualizado apgtos diferente da cond. pagto
oPgtos:Refresh()

@ aPosObjPg[1,3]-aPosObjPg[1,1]-10, 090 SAY oDescCondPg VAR cDescCondPg PIXEL OF oPanVAPg

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Monta os botoes com base nas administradoras financeiras     ³
//³ Mantem sempre Dinheiro e cheque como os primeiros e          ³
//³ Condicao Negociada por ultimo                                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aFormPgtos	:= {}
DbSelectArea("SX5")
If DbSeek(xFilial("SX5")+"24"+cMvSimb1)	.And. (!cMvSimb1 $ cMNFormPg) .And. (!"R$" $ cMNFormPg)  // Dinheiro
	If (! lLJ7020) .OR. ( lLJ7020 .AND. ExecBlock("LJ7020", .F., .F., { Upper(AllTrim(X5Descri())) }) )
		aAdd( aFormPgtos, { AllTrim(SX5->X5_CHAVE), X5Descri() })
	EndIf
EndIf
If DbSeek(xFilial("SX5")+"24"+MVCHEQUE)	.And. (!MVCHEQUE $ cMNFormPg) .And. (!"CH" $ cMNFormPg) // Cheque
	If (! lLJ7020) .OR. ( lLJ7020 .AND. ExecBlock("LJ7020", .F., .F., { Upper(AllTrim(X5Descri())) }) )
		aAdd( aFormPgtos, { AllTrim(MVCHEQUE), X5Descri() })
	EndIf
EndIf

DbSelectArea("SAE")
SAE->( DbSetOrder(1) )	//AE_FILIAL + AE_COD
SAE->( DbSeek(xFilial("SAE")) )

lAddBtn := .T.

While SAE->AE_FILIAL == xFilial("SAE") .AND. SAE->( !Eof() )
	If !(AllTrim(SAE->AE_TIPO) $ MVCHEQUE .OR. IsMoney(SAE->AE_TIPO))
	    If SX5->(DbSeek(xFilial("SX5")+"24"+AllTrim(SAE->AE_TIPO)))
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ponto de entrada para informar se o botão de forma de pagto deve ou não aparecer.³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lLJ7020 .AND. !lFtvdVer12
				lAddBtn := ExecBlock("LJ7020", .F., .F., { Upper(AllTrim(X5Descri())) })
			EndIf

			If lFTVD7020 .AND. lFtvdVer12
				lAddBtn := ExecBlock("FTVD7020", .F., .F., { Upper(AllTrim(X5Descri())) })
			EndIf

			If lAddBtn

		    	If aScan( aFormPgtos, { |x| AllTrim(x[1]) == Alltrim(SAE->AE_TIPO) } ) == 0 .And. (!Alltrim(SAE->AE_TIPO) $ cMNFormPg)
		    		aAdd( aFormPgtos, { AllTrim(SAE->AE_TIPO), X5Descri() } )
		    	EndIf

				If (( nPosAE_MSBL > 0 .AND. SAE->AE_MSBLQL <> "1" ) .OR. nPosAE_MSBL == 0)
					aAdd( aAdmFinanc, { AllTrim(SAE->AE_TIPO), SAE->AE_DESC, SAE->AE_COD } )
		    	EndIf
		    EndIf

		EndIf

	EndIf

	DbSkip()
End

If ((! lLJ7020 .AND. !lFtvdVer12) .OR. ( lLJ7020 .AND. ExecBlock("LJ7020", .F., .F., { Upper(STR0033) }) )) .And. (!"CN" $ cMNFormPg)  // Cond.Negociada //"Cond.Negociada"
	aAdd( aFormPgtos, { "CN", STR0033 } )   // Cond.Negociada //"Cond.Negociada"
EndIf

If ((!lFTVD7020 .AND. lFtvdVer12) .OR. (lFTVD7020 .AND. ExecBlock("FTVD7020", .F., .F., { Upper(STR0033) }))) .And. (!"CN" $ cMNFormPg) // Cond.Negociada //"Cond.Negociada"
	aAdd( aFormPgtos, { "CN", STR0033 } )   // Cond.Negociada //"Cond.Negociada"
EndIf

If lAtivaMn .And. (!"MN" $ cMNFormPg)
	aAdd( aFormPgtos, { "MN", STR0176, "" } )   // "Multi Negociação"
EndIF

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - Cartao Fidelidade³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLjcFid
	DbSelectArea("SX5")
	If DbSeek(xFilial("SX5")+"24"+"FID") .And. (!"FID" $ cMNFormPg) 	// Cartao fidelidade
		aAdd( aFormPgtos, { AllTrim(SX5->X5_CHAVE), X5Descri() })
	EndIf
EndIf


If ((! lLJ7020 .AND. !lFtvdVer12) .OR. ( !lFtvdVer12 .And. lLJ7020 .AND. ExecBlock("LJ7020", .F., .F., { Upper(STR0034) }) )) // Cond.Negociada //"Cond.Negociada"
	aAdd( aFormPgtos, { ""  , STR0034 } )   // Zerar Pagamentos //"Zerar Pagamentos"
ElseIf ((! lFTVD7020 .AND. lFtvdVer12) .OR. (lFtvdVer12 .And. lFTVD7020 .AND. ExecBlock("FTVD7020", .F., .F., { Upper(STR0034) }) )) // Cond.Negociada //"Cond.Negociada"
	aAdd( aFormPgtos, { ""  , STR0034 } )   // Zerar Pagamentos //"Zerar Pagamentos"
EndIf

If !lFtvdVer12

	If Len( aAdmFinanc ) > 1
		aSort( aAdmFinanc, 1, Len(aAdmFinanc), { |x,y| x[1] + Upper(x[2]) < y[1] + Upper(y[2]) })
	EndIf

ElseIf lFtvdVer12

	If Len( aAdmFinanc ) > 4
		aSort( aAdmFinanc, 3, Len(aAdmFinanc)-4, { |x,y| x[1]+x[2] < y[1]+y[2] })
	EndIf

EndIf

If Len( aFormPgtos ) > 4
	aSort( aFormPgtos, 3, Len(aFormPgtos)-4, { |x,y| x[1]+x[2] < y[1]+y[2] })
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de entrada para criação de um botao customizado                                           ³
//³------------------------------------------------------------------------------------------------³
//³Observacao : So podera ser incluido um unico botao para customizacao                            ³
//³o segundo parametro devera ser passado como caracter                                            ³
//³------------------------------------------------------------------------------------------------³
//³Retorno  Array com dados do Botao:                                                              ³
//³aRet[1]:='Nome do Botao"                                                                        ³
//³aRet[2]:='Nome da funcao que sera executada                                                     ³
//³Exemplo :                                                                                       ³
//³aRet:= {'Gabryella',Execblock('GABCN',.F.,.F.)}                                                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock("LJ7007") .AND. !lFtvdVer12

	aRet := ExecBlock("LJ7007",.F.,.F.)

    If ValType(aRet)=='A' .AND. Len(aRet) % 2 <> 0
    	If !lAutoExB
			Aviso( STR0011 , STR0035 , {"Ok"} ) //"Inconsistência"###"Verifique o retorno do ponto de entrada LJ7007!"
		Else
			ConOut(STR0035)
		EndIf
		Return Nil
    EndIf

    For nX := 1 To Len(aRet) Step 2
	    aAdd( aFormPgtos, { "BOTAO_CUSTOMIZADO", aRet[nX] ,,, aRet[nX+1]} )		// Botão customizado
	Next nX

EndIf

If ExistBlock("FTVD7007") .AND. lFtvdVer12

	aRet := ExecBlock("FTVD7007",.F.,.F.)

    If ValType(aRet)=='A' .AND. Len(aRet) % 2 <> 0
    	If Type("lAutoExec") <> "L" .OR. !lAutoExec
			Aviso( STR0011 , STR0035 , {"Ok"} ) //"Inconsistência"###"Verifique o retorno do ponto de entrada LJ7007!"
		Else
			ConOut(STR0035)
		EndIf
		Return Nil
    EndIf

    For nX := 1 To Len(aRet) Step 2
	    aAdd( aFormPgtos, { "BOTAO_CUSTOMIZADO", aRet[nX] ,,, aRet[nX+1]} )		// Botão customizado
	Next nX

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Executa a Template Function "TPLDRO_PGTO", para que o array de formas de pagamento seja limpo e ³
//³nenhum botão de forma de pagamento seja carrecado                                               ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistTemplate("TPLDRO_PGTO")
	lCriaBt := ExecTemplate("TPLDRO_PGTO",.F.,.F.)
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Faz o calculo para saber quantos botoes cabem por linha      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nItensLin := Int( (aPosObjPg[1,4] - aPosObjPg[1,2] - 8) / 54 )
If Len(aFormPgtos) < nItensLin
	nItensLin := Len(aFormPgtos)
EndIf

For nX := 1 to nItensLin
	aAdd( aObjButtons, { 015, 050, .T., .T. } )
Next nX
aInfButtons := { 0, 0, aPosObjPg[1,4]-aPosObjPg[1,2], aPosObjPg[1,3]-aPosObjPg[1,1], 4, 4 }
aPosObjBut 	:= MsObjSize( aInfButtons, aObjButtons, .T., .T. )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Prepara a array aFormPgtos para os Blocos de Codigo          ³
//³ para o Action dos Botoes                                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 to Len(aFormPgtos)
	aAdd( aFormPgtos[nX], "oBtn"+StrZero(nX,2) )
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Monta os Botoes                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nX := 1
nLinha := 1
While nX <= Len( aFormPgtos )
	nY := 1
	While nY <= nItensLin .AND. nX <= Len( aFormPgtos )
		@ 19*(nLinha-1)+4, aPosObjBut[nY,2] BUTTON aFormPgtos[nX][3] PROMPT Lj7TitBotoes(aFormPgtos,@aTecAtalho,nX) PIXEL ;
		SIZE 50,15 MESSAGE Capital(AllTrim(aFormPgtos[nX][2])) OF oPanVAPg
		If nOpc <> 2
			If nOpc <> 3 .AND. !Empty( Trim(SL1->L1_FILRES + SL1->L1_ORCRES) )
				bBloco := &("{ || Aviso( '" + STR0001 + "', '" + STR0002 + "',{'" + STR0003 + "'} ) }" ) //'Atenção'###'Não é permitida a alteração das formas de pagamento de um orçamento gerado com reserva.'###'Ok'
			Else
				If aFormPgtos[nX][1] == "CN"
					bBloco := &("{ || Lj7CondNeg(oPanCondNeg) }" )
				ElseIf aFormPgtos[nX][1] == "MN" .AND. lAtivaMn
					bBloco := &("{ || LJ7MultNeg(oPanCondNeg) }" )
				ElseIf Empty(aFormPgtos[nX][1])
					If lLj7010
						bBloco := &("{ || U_LJ7010() }")
					Else
						If lLjVldPbm 
                    		bBloco := &("{ || Lj7ZeraPgtos(@lTefPendCS, @aTefBKPCS,,IIF(LjVldPbm(),{'CO'},{}),@nVlrAcrsFi)}")
                    	Else
                    		bBloco := &("{ || Lj7ZeraPgtos(@lTefPendCS, @aTefBKPCS,,,@nVlrAcrsFi)}")
                    	EndIf
					EndIf
				ElseIf aFormPgtos[nX][1] == "BOTAO_CUSTOMIZADO" //Executa a funcao do botao customizado
					bBloco := &("{ || "+aFormPgtos[nX][5]+"}" )
				Else
					bBloco := &("{ || M->LQ_CONDPG:=Space(nTamE4_COD), Lj7CondPg( 1, '" + aFormPgtos[nX][1] + "',Nil ,Nil ,Nil ,Nil ,Nil ,Nil ,Nil , lTefPendCS, Nil, Nil, @nVlrAcrsFi) }")
				EndIf
			EndIf
		EndIf
		aFormPgtos[nX][3]:bAction := bBloco
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Ponto de Entrada para desabilitar os botoes de Formas de Pagto desejados               ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		lHideBtn := .F.
		If ExistBlock("LJ7023") .AND. !lFtvdVer12
			lHideBtn := ExecBlock("LJ7023", .F., .F.,{AllTrim(Upper(aFormPgtos[nX][2]))})
		EndIf
		If ExistBlock("FTVD7023") .AND. lFtvdVer12
			lHideBtn := ExecBlock("FTVD7023", .F., .F.,{AllTrim(Upper(aFormPgtos[nX][2]))})
		EndIf
		If lHideBtn
			aFormPgtos[nX][3]:Hide()
		EndIf

        //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
        //³Ponto de Entrada para DESATIVAR os botoes de Formas de Pagto desejados, o botao fica presente na tela, porem sem acao.³
        //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
        lDisableBt := .F.
        If ExistBlock("LJ7027")
            lDisableBt := ExecBlock("LJ7027", .F., .F.,{AllTrim(Upper(aFormPgtos[nX][2]))})
        EndIf
        If lDisableBt
            aFormPgtos[nX][3]:Disable()
        EndIf

		nX ++
		nY ++
	End
	nLinha ++
End
aLayPgtos  := AClone(aFormPgtos)
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³                                                              ³
//³            Monta o panel "Condicao Negociada"                ³
//³                                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz o calculo para montar os objetos na tela                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nObjetos := (If (SL1->(FieldPos("L1_DIAFIXO")) > 0, 8, 7))
For nX := 1 to nObjetos
	aAdd( aObjCondNeg, { 015, 050, .T., .T. } )
Next nX
aInfCondNeg := { 0, 0, aPosObjPg[1,4]-aPosObjPg[1,2], aPosObjPg[1,3]-aPosObjPg[1,1], 4, 4 }
aPosCondNeg 	:= MsObjSize( aInfCondNeg, aObjCondNeg, .T. )

@ aPosCondNeg[1][1], 010 SAY STR0036 PIXEL OF oPanCondNeg //"Tipo Juros"
@ aPosCondNeg[1][1], 080 MSCOMBOBOX aDadosCNeg[2][1] VAR aDadosCNeg[1][1] ITEMS aTipoJuros SIZE 60,07 PIXEL OF oPanCondNeg
aDadosCNeg[2][1]:cSx1Hlp := "LQ_TIPOJUR"
aDadosCNeg[2][1]:bChange := { || M->LQ_TIPOJUR := Val(Subst(aDadosCNeg[1][1],1,1)) }

@ aPosCondNeg[2][1], 010 SAY STR0037 PIXEL OF oPanCondNeg //"Data 1a.Parcela (Entrada)"
@ aPosCondNeg[2][1], 080 MSGET aDadosCNeg[2][2] VAR aDadosCNeg[1][2] VALID aDadosCNeg[1][2]>=dDataBase SIZE 45,07 PIXEL OF oPanCondNeg
aDadosCNeg[2][2]:cSx1Hlp := "LJ701DTPAR"

@ aPosCondNeg[3][1], 010 SAY STR0038 PIXEL OF oPanCondNeg //"Valor de Entrada $"
@ aPosCondNeg[3][1], 080 MSGET aDadosCNeg[2][3] VAR aDadosCNeg[1][3] VALID aDadosCNeg[1][3]>=0 SIZE 60,07 PICTURE PesqPict("SL1","L1_VLRTOT",,nMoedaCor) PIXEL OF oPanCondNeg
aDadosCNeg[2][3]:cSx1Hlp := "LQ_ENTRADA"

@ aPosCondNeg[4][1], 010 SAY STR0039 PIXEL OF oPanCondNeg //"Taxa de Juros %"
@ aPosCondNeg[4][1], 080 MSGET aDadosCNeg[2][4] VAR aDadosCNeg[1][4] SIZE 20,07 PICTURE "@E 999.99" PIXEL OF oPanCondNeg
aDadosCNeg[2][4]:cSx1Hlp := "LQ_JUROS"

@ aPosCondNeg[5][1], 010 SAY STR0040 + " " + STR0210 PIXEL OF oPanCondNeg //"#Parcelas" #(Parcelas+Entrada)"
@ aPosCondNeg[5][1], 080 MSGET aDadosCNeg[2][5] VAR aDadosCNeg[1][5] VALID aDadosCNeg[1][5]>0 SIZE 13,07 PICTURE "99" PIXEL OF oPanCondNeg
aDadosCNeg[2][5]:cSx1Hlp := "LQ_PARCELA"

@ aPosCondNeg[6][1], 010 SAY oIntDVenc VAR If(aDadosCNeg[1][8],STR0103,STR0041) PIXEL OF oPanCondNeg //"Intervalo"
@ aPosCondNeg[6][1], 080 MSGET aDadosCNeg[2][6] VAR aDadosCNeg[1][6] SIZE 13,07 PICTURE "99" PIXEL OF oPanCondNeg
aDadosCNeg[2][6]:cSx1Hlp := "LQ_INTERV"

@ aPosCondNeg[7][1], 010 CHECKBOX aDadosCNeg[2][7] VAR aDadosCNeg[1][7] PROMPT STR0042 SIZE 120,07  WHEN (Subst(aDadosCNeg[1,1],1,1)$"12") PIXEL OF oPanCondNeg //"Calcula o Juros incluindo o valor de Entrada?"

If SL1->(FieldPos("L1_DIAFIXO")) > 0
	@ aPosCondNeg[8][1], 010 CHECKBOX aDadosCNeg[2][8] VAR aDadosCNeg[1][8] PROMPT STR0102 SIZE 100,07  WHEN (Subst(aDadosCNeg[1,1],1,1)$"123") PIXEL OF oPanCondNeg; //"Dia Fixo"
	ON CHANGE (If (aDadosCNeg[1][8],aDadosCNeg[1][6]:=Day(dDataBase),aDadosCNeg[1][6] := 30), aDadosCNeg[2][6]:Refresh(), oIntDVenc:Refresh())
EndIf

DEFINE SBUTTON FROM aPosCondNeg[nObjetos][1],aPosObjPg[1,4]-aPosObjPg[2,1]-068 TYPE 1 ENABLE OF oPanCondNeg ;
ACTION (	oPanCondNeg:Hide(), oPanCondNeg:lReadOnly:=.T.			,;
			M->LQ_CONDPG:=cDescCondPg:=cCondSE4:=Space(nTamLQ_CON)	,;
			Lj7CondPg( 	1			 		, "CN"		 , aDadosCNeg[1]	, Nil	,;
						aDadosCNeg[1][8]	, Nil		 , Nil				, Nil  	,;
						nOpc			 	, lTefPendCS , Nil				, If(nOpc <> 4, aDadosCNeg[1][4] <> M->LQ_JUROS, .T.) ,;
						@nVlrAcrsFi	 		))

DEFINE SBUTTON FROM aPosCondNeg[nObjetos][1],aPosObjPg[1,4]-aPosObjPg[2,1]-032 TYPE 2 ENABLE OF oPanCondNeg ACTION (oPanCondNeg:Hide(),oPanCondNeg:lReadOnly:=.T.)

RestArea( aArea )
Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7CondPg ºAutor  ³ Vendas Clientes    º Data ³  12/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Monta o browse  com as parcelas para o pagamento            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³void Lj7CondPg( ExpN1, ExpC2, ExpA3, ExpL4 )                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpN1 - Tipo da condicao                                    º±±
±±º          ³        1 - Chamada por um botao da tela de negociacao      º±±
±±º          ³        2 - Chamada por uma condicao de pagamento (SE4)     º±±
±±º          ³                                                            º±±
±±º          ³ExpC2 - Forma de pagto. Ex. "R$" / "CH" (Se ExpN1 == 1)     º±±
±±º          ³        ou                                                  º±±
±±º          ³        Codigo da condicao de pagamento (Se ExpN1 == 2)     º±±
±±º          ³                                                            º±±
±±º          ³ExpA3 - Dados para o calculo da condicao de pagamento se    º±±
±±º          ³        ExpC2 == "CN" (Condicao Negociada)                  º±±
±±º          ³        [1] - Tipo Juros (1)-Simples                        º±±
±±º          ³                         (2)-Composto                       º±±
±±º          ³                         (3)-Price                          º±±
±±º          ³        [2] - Data de Entrada                               º±±
±±º          ³        [3] - Valor da Entrada                              º±±
±±º          ³        [4] - Taxa de Juros                                 º±±
±±º          ³        [5] - Quantidade de parcelas                        º±±
±±º          ³        [6] - Intervalo                                     º±±
±±º          ³        [7] - Calcula juntos na 1a parcela (.T. ou .F.)     º±±
±±º          ³        [8] - Re-Calcula parcelas (.T. ou .F.)              º±±
±±º          ³                                                            º±±
±±º          ³ExpL4 - .T. - Atualiza ListBox                              º±±
±±º          ³        .F. - Apenas faz o calculo (para atualizacao das    º±±
±±º          ³              variaveis).                                   º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7CondPg( nTipo		, cCondicao		, aCondNeg	, lAtuList 	,;
					lDiaFixo	, cFormTroca	, cFormaId	, nFormValor,;
					nOpc		, lTefPendCS	, lAtuParc	, lAltCond	,;
					nVlrAcrsFi	, lRecal		, lRegraDesc, nPerDesc	,;
					cAlterCond	)

Local nVlrPago			:= 0    													// Valor pago
Local nPosForma			:= 0  														// Posicao da forma de pagamento
Local aRetPgto			:= {}                                  						// Array de Pagtos
Local aParcelas 		:= {}														// Array de parcelas
Local aE4 				:= {}														// Array do E4
Local aParcDiaFixo		:= {}														// Array parcelas dia fixo
Local nSobraNCC			:= 0														// Tira o frete e a NCC para nao entrar no calculo de juros
Local nX          		:= 0														// Contador
Local nVlrParc          := 0  														// Valor da parcela
Local cLj7015           := ""  														// Ponto de Entrada LJ7015
Local cFTVD7015         := ""  														// Ponto de Entrada FTVD7015
Local nValICMSSol       := 0														// Valor Icms solidario
Local nValor            := 0														// Total - descontos
Local dDataHj          																// Data atual
Local nPos				:= 0														// Data de hoje
Local cSimbMoeda		:= SuperGetMV("MV_SIMB"+Ltrim(Str(nMoedaCor)))				// Simbolo da moeda
Local nVlrAux 		    := 0 														// Valor auxiliar
Local cCondPad			:= SuperGetMV( "MV_CONDPAD" ) 								// Condicao de pagamento padrao
Local nTroco			:= 0														// Variavel que recebe o troco caso o parametro MV_LJTRLOC = .T.
Local lContinua			:= .T.														// Define se Continua a Execucao
Local nValAbISS         := 0														// Valor do ISS
Local nVlrSub           := 0														// Valor do Sub Total da Venda
Local nVlrParcela       := 0														// Valor da Parcela
Local nValFrete 		:= 0       													// Valor do frete
Local nVlrSoma          := 0														// Auxiliar para Criacao da Parcela
Local nDifNCCTot		:= 0 														// Diferença entra NCC e Total Venda
Local lFreteAlt 		:= .F.														// Indica que ocorreu alteracao no valor do frete, despesa ou seguro.
Local cFormVale			:= IIf(SuperGetMV("MV_LJVALEP",,.F.),"VA|VP","VA")			// Utiliza Vale Presente
Local nAux              := 0                                                        // Variavel auxiliar
Local nValmoed1			:= 0														// Valor da moeda 1
Local nValorAcrs		:= 0														// Valor do acrescimo na condição de pagamento
Local nVlAuxAcrs		:= 0														// Valor auxiliar do acrescimo na condição de pagamento
Local lLj7063			:= ExistBlock("LJ7063")
Local lAutoExB 			:= IsBlind()												// Verifica se a rotina sera executada via execauto ou nao
Local nDesc             := 0														// Percentual de desconto por tipo de pagamento
Local aTipoPagto		:= {}														// Armazena o tipo de pagto quando selec. na tela o tipo
Local nExcedent         := 0                                                        // Diferenca a ser abatida no valor do frete quando utilizada NCC
Local nDiferenca        := 0 														// Valor de juros aplicada na condição negociada
Local lTefMult			:= SuperGetMV("MV_TEFMULT")                                 // Utiliza multiplas transacoes TEF
Local cFormPagto		:= "" 														// Forma de Pagamento
Local cCondPagto		:= "" 														// Condicao de Pagamento (SE4)
Local lAbateISS 		:= .F. 														// Identifica se abate ou nao o ISS do valor da venda
Local lICMSSolid        := .F.                                                      // Calcula ICMS Solidario.
Local nPosMoney			:= 0														// Posicao no array aRetPgto que eh Moeda
Local lLjGetDFP			:= ExistFunc("LjGetDesFP")									// Verifica se existe a funcao LjGetDesFP(LOJA3026)
Local lEmitNfce			:= ExistFunc("LjEmitNFCe") .AND. LjEmitNFCe()				// Sinaliza se utiliza NFC-e
Local nVlrTotAux		:= 0														// Variavel auxiliar para calcular descontos da Regra de Desconto Varejo
Local nDescRGAux		:= 0														// Variavel auxiliar para calcular descontos da Regra de Desconto Varejo
Local nPercRGAux		:= 0														// Variavel auxiliar para calcular descontos da Regra de Desconto Varejo
Local lHomolPaf			:= ExistFunc("LjHomolPaf") .AND. LjHomolPaf()
Local lLjNfPafEcf		:= LjNfPafEcf(SM0->M0_CGC)
Local nIcmSolDif		:= 0														// Diferenca do valor do ICMS Solidario com e sem frete aplicado
Local lRgAcumulAnt		:= .T.														// Armazena se a regra do desconto for acumulativa antes de entrar na condicao de pagamento
Local cRGAdmFin 		:= "" 														// Administradora financeira (para verificar se tem regra de desconto configurada para a administradora financeira em questao)
Local lJob				:= Type("lAutoExec") == "L" .AND. lAutoExec					// Define se modo Job
Local nValDescAnt		:= 0														// Valor do Desconto Anterior
Local nValIpi			:= IIF(MaFisFound("NF"), MaFisRet(,'NF_VALIPI'), 0)
Local lAbatPNCC			:= !(SuperGetMV("MV_LJABNCC",,.T.)) .And. nNCCUsada > 0		// Caso exista valor de NCC, prioriza o abatimento da mesma, quanto a cond. pagamento.
Local lVldUserCpg		:= .T.
Local lMvLjAltPG		:= SuperGetMV("MV_LJALTPG",,.T.)
Local lMultNeg   		:= SuperGetMV("MV_LJMULTN", , .F.)
Local nMNCC				:= 0
Local lLjIcmJr  		:= SuperGetMv("MV_LJICMJR", , .F.)							// Não incide ICMS sobre Juros
Local lpTPAbISS			:= (SuperGetMV("MV_TPABISS", NIL, "1") == "2")				// GetMv do MV_TPABISS
Local nMvLjTpDes		:= SuperGetMv( "MV_LJTPDES", , 0 )							// Indica qual desconto sera' utilizado 0 - Antigo / 1 - Novo (objeto)
Local nValDscFin		:= 0														// Valor do desconto na condição de pagamento
Local nDescFin			:= 0														// Valor do Desconto Financeiro
Local lAutomato			:= If(Type("lAutomatoX")<>"L",.F.,lAutomatoX)
Local lIntegDef			:= If(Type("lAutoExec") == "L", lAutoExec, .F.) .And. FWHasEAI("LOJA701",, .T., .T.) .AND. !lAutomato//Integracao via Mensagem Unica
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12		:= LjFTVD()													// Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local lVldUser			:= .T.

Default aCondNeg 		:= {}                                                     	// Default do array aCondNeg igual a vazio
Default lAtuList        := .T.        												// Default da variavel lAtulist é T
Default lDiaFixo		:= .F.														// Default da variavel lDiaFixo e F
Default cFormTroca		:= ""														// Default da variavel cFormaTroca e vazio
Default cFormaId		:= If(lVisuSint,Space(TamSX3("L4_FORMAID")[1]),Space(01)) 	// Identificação do cartao
Default nFormValor		:= 0														// Default da variavel nFormaValor é 0
Default nOpc			:= 0														// Default da variavel nOpc é 0
Default lAtuParc        := .F.                                                     	// Verifica se atualiza a parcela
Default lAltCond		:= .F.              										// Verifica se veio do menu ou ira finalizar a venda direto
DEFAULT lRecal			:= .F.
Default nVlrAcrsFi		:= 0
Default lRegraDesc		:= .F.														// Controla se aplica a regra de desconto
Default nPerDesc		:= 0														// Retorna o percentual de desconto da regra
DEFAULT cAlterCond		:= ""

If !lAtuPgto .AND. lAtuParc
	lAtuPgto := lAtuParc
EndIf

If !(MafisFound("NF"))
	Return Nil
EndIf

LjGrvLog( NIL, "Browse com Parcelas - aCondNeg", aCondNeg)
LjGrvLog( NIL, "Browse com Parcelas - cCondicao", cCondicao)

If nTipo == 1 //Chamada por um botao da tela de negociacao
	cFormPagto	:= cCondicao	// Forma de Pagamento
	cCondPagto  := Nil
ElseIf nTipo == 2 //Chamada por uma condicao de pagamento (SE4)
	cFormPagto	:= Nil
	cCondPagto	:= cCondicao	// Condicao de Pagamento (SE4)
EndIf 

// Verifica o quanto da venda já foi pago
If cPaisLoc == "BRA" .AND.!lAutoExB
	aEval( aPgtos, {|x| nVlrPago += x[2]} )
	nVlrPago += nNCCUsada
EndIf

//Zera as formas de pagamento quando limpar a Condição de Pagamento ou o valor da venda for diferente das parcelas
//Verificar se é finalização, pois caso houver condição negociada o M->LQ_CONDPG estara em "CN" ou em Branco "", nao devendo zerar pagamentos
If nTipo == 2 .And. Empty(M->LQ_CONDPG) .And. nVlrPago <> Lj7T_Total(2) .AND. !IsInCallStack("Lj7DefPag")
	Lj7ZeraPgtos()
EndIf

nVlrPago := 0	//resetamos o valor, pois ela é usada abaixo

If Len(aCondNeg) >= 7 .AND. aCondNeg[4] < 0
	If !lAutoExB
		MsgStop(STR0095) //"O campo Taxa Juros deve ter valor positivo."
	Else
		ConOut(STR0095)
	EndIf
	lContinua := .F.
EndIf

If ( Len(aCondNeg) >= 7 ) .AND.  (aCondNeg[4] > 0 )
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se o Usuario tem acesso para efetuar acrescimo ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !ChkPsw(46)
		lContinua := .F.
	EndIf
EndIf

If lContinua .AND. nTipo == 1 
	If !lFtvdVer12 .AND. ExistBlock("LJ7015")
		LjGrvLog( NIL, " Antes da execução do P.E. LJ7015",{lRecebe,cCondicao})
		cLj7015 := ExecBlock("LJ7015", .F., .F., {lRecebe,cCondicao})
		LjGrvLog( NIL, " Depois da execução do P.E. LJ7015",cLj7015)
		If !(Empty(cLJ7015) .OR. cCondicao $ cLj7015)
			lContinua := .F.
		EndIf
	EndIf
	
	If lFtvdVer12 .AND. ExistBlock("FTVD7015")
		LjGrvLog( NIL, " Antes da execução do P.E. FTVD7015",{lRecebe,cCondicao})
		cFTVD7015 := ExecBlock("FTVD7015", .F., .F., {lRecebe,cCondicao})
		LjGrvLog( NIL, " Depois da execução do P.E. FTVD7015",cFTVD7015)
		If !(Empty(cFTVD7015) .OR. cCondicao $ cFTVD7015)
			lContinua := .F.
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o usuario pode utilizar condicoes negociadas     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lContinua
	If lAtuCond
		lAtuCond := .F.
		If nOpc == 3 .AND. Empty(cAlterCond) .AND. lFtvdVer12
			cAlterCond := cCondPad
		EndIf
	Else
		If lAtuList
			If cCondicao <> "CN"  .AND. cCondicao <> SuperGetMV( "MV_CONDPAD" )    // Condicao de pagamento padrao				
				If IIf(ValType(lAutoExec) == "L",!lAutoExec,.T.) .AND. !LjProfile( 9 )
					If !lAutoExB
						MsgStop(STR0043) //"Caixa não autorizado"
					Else
						ConOut(STR0043) //"Caixa não autorizado"
					EndIf
					LjGrvLog( NIL, STR0043 )
					lContinua		:= .F.
				EndIf
			EndIf
		EndIf
	EndIf
EndIf

If lContinua
	If lNovRegDesc .AND.;
	( IIf(ExistFunc("LJ3026_VER") .And. LJ3026_VER()>="20131003", LjGetDesFP(3), .F.) .OR. ;
	  (ExistFunc("LjVerRegAdm") .AND. LjVerRegAdm() )  )
		LjSelAdmRG(cFormPagto,@lContinua,@cRGAdmFin, cCondicao, cFormaID)
	EndIf
EndIf

If lContinua

	If ExistFunc( "LJGETRACUMUL" )
		lRgAcumulAnt := LjGetRAcumul()
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Quando altera cond. de pgto , zera desconto para recalcular     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//se for Desc. Total c/ Forma de Pgto(Regra de Desconto Varejo) nao zera as variaveis de desconto
	If lNovRegDesc .AND. aDesconto[1] == 2 .AND. IIf(lLjGetDFP, (LjGetDesFP(2) .OR. LjGetDesFP(3)) , .T.)
		aDesconto[2]:= 0
		aDesconto[3]:= 0
		Lj7T_DescP( 2, aDesconto[2] )
		Lj7T_DescV( 2, aDesconto[3] )
	EndIf

	If M->LQ_FATOR > 0
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Na finaliz. da venda, verifica primeiro se a cond. foi alterada ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nOpc == 4
			If (M->LQ_CONDPG <> SL1->L1_CONDPG)
				M->LQ_FATOR := 0
				M->LQ_ADMFIN:= ""
			EndIf
		Else
			M->LQ_FATOR := 0
			M->LQ_ADMFIN:= ""
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica quanto ja foi pago³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc == "BRA"
		If !lAutoExB
			aEval( aPgtos, {|x| nVlrPago+=x[2] } )
  		EndIf
	Else
	   aEval( aPgtos, {|x| nVlrPago+=Round(xMoeda(x[2],x[_MOEDA],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)})
	EndIf
	nVlrPago := nVlrPago + nNCCUsada  // Considera a NCC selecionada
	lj7Arred(1,3)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Monta as parcelas de acordo com o Botao selecionado          ³
	//³ ou com a condicao de pagamento (SE4) escolhida               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nTipo == 1 .AND. cCondicao <> "CN"
		
	    If lLayAway
	       //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	       //³ Para Lay-Away jah preenche as parcelas com a forma de paga-  ³
	       //³ mento NF - Loc. POR|EUA                                      ³
	       //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	       aParcelas := { dDataBase, Lj7T_Total( 2 ) - nVlrPago, cCondicao, "", nMoedaCor, dDataBase, Space(01) }

	    ElseIf cPaisLoc == "BRA"
	    	nValAbISS := MaFisRet(,'NF_VALISS')
			lAbateISS := LjxDAbISS(cCondPagto,cFormPagto,nValAbISS)
			nValor := Lj7T_Total( 2 )-nVlrPago - If( lAbateISS, nValAbISS, 0 )
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Nao aceitar parcela negativa³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nValor < 0
				nValor := 0
			Else

				If !lJob .AND. lNovRegDesc .AND. ExistFunc("RGDesTol") .AND. ExistFunc("CalPerc")
					//se for Desc. Total c/ Forma de Pgto(Regra de Desconto Varejo) nao zera as variaveis de desconto
					If lLjGetDFP .AND. LjGetDesFP(3)
					    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³ Na troca da condicao de pagto                        ³
						//³ Zera desconto,					                     ³
						//³ Zera as variaveis que indicam fator de financiamento ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						LjValidPer(3)
						//Recalcula o valor total
						nValor := Lj7T_Total( 2 )-nVlrPago - If( lAbateISS, nValAbISS, 0 )
					EndIf
					//Apura o valor do Desconto Concebido anteriormente, caso necessite de recálculo
					nValDescAnt :=   Lj7T_DescV(2)
					//Verifica se o Total não foi zerado
					If nValDescAnt == 0 .AND. (nValDescAnt <> (Lj7T_SubTotal(2) - Lj7T_Total(2) ) )
						nValDescAnt :=   Lj7T_SubTotal(2) - Lj7T_Total(2)
						If nValDescAnt < 0
							nValDescAnt := 0
						EndIf
						Lj7T_DescV( 2, nValDescAnt)
					EndIf

					//se o desconto ja foi aplicado para a forma de pagamento, nao executa a regra de desconto
					If Iif( ExistFunc("LjVldFrmPg"), LjVldFrmPg(cFormPagto), .T. )

						LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
									Lj7T_DescV(2)	, Lj7T_Total(2)	)

		   				// Add os pagamentos realizados para analisar regra de desconto
					    aTipoPagto := {}
					    If Len(aPgtos) > 0
					    	For nX := 1 To Len(aPgtos)
					    		AADD(aTipoPagto,{CTOD(" "),	aPgtos[nX][2],aPgtos[nX][3],""})
					    	Next nX
					    EndIf
						AADD(aTipoPagto,{CTOD(" "),nValor,cCondicao,cRGAdmFin})

						// Verifica regra de desconto , mas para recebimento não se aplica a regra de desconto varejo
						If !lRecebe
							nDesc := RGDesTol(	.T.				,nValor		, cCondPagto	, aTipoPagto,;
												M->LQ_CLIENTE 	,M->LQ_LOJA , Lj7T_Total(2)	, cFormPagto,;
												.T. )
						EndIf

						If nDesc > 0
							nDescRGAux := lj7Arred(2, 3,  ((nDesc / 100) * nValor) )  //Valor do desconto a ser aplicado (regra de desconto)

							//Abate o valor descontado no total
							Lj7T_DescV( 2, nValDescAnt + nDescRGAux  )
							//Valida por valor
							LjValidPer(1)

							//Abate o Desconto no Valor da Forma
							nValor -= nDescRGAux

							LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
									Lj7T_DescV(2)	, Lj7T_Total(2)	)
							aDesconto := { 2, Lj7T_DescP(2), Lj7T_DescV(2) }
						EndIf
					EndIf

				EndIf

			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Seleciona o tipo de pagamento manualmente, clicando³
			//³ em cada botao de pgto.                            ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			LjGrvLog( NIL, "Browse com Parcelas - Antes de AltPgt - aParcelas", aParcelas)
			aParcelas := Lj7AltPgt( Nil, {dDataBase,nValor,cCondicao,.F.}, lAtuCond, lTefPendCS, cRGAdmFin )
			LjGrvLog( NIL, "Browse com Parcelas - Depois de AltPgt - aParcelas", aParcelas)

			//Usuário cancelou a forma de Pagamento, nesse caso volta o valor do desconto concebido
			If lNovRegDesc .AND. Len(aParcelas) == 0  .AND. nDesc > 0
			    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ No cancelamento da condicao de pagto                        ³
				//³ Zera desconto,					                     ³
				//³ Zera as variaveis que indicam fator de financiamento ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				//se for desconto no total por forma de pagamento (Regra de Desconto Varejo) nao zera as variaveis de desconto
				If lLjGetDFP .AND. LjGetDesFP(3)
					LjValidPer(3)

				ElseIf lLjGetDFP .AND. !LjGetDesFP(3)
                    //Volta o Valor do Desconto concebido pela forma
					Lj7T_DescV( 2, nValDescAnt)
					LjValidPer(1)
				EndIf
				LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
							Lj7T_DescV(2)	, Lj7T_Total(2)	)
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Recalcula regra de desconto pois o valor pode ser  ³
			//³proporcional ao pagamento alterado                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lNovRegDesc .AND. ExistFunc("RGDesTol") .AND. ExistFunc("CalPerc")  .AND. Len(aParcelas) > 0 .AND. ;
				aParcelas[2] < (Lj7T_Total( 2 ) - nVlrPago)

			    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Na troca da condicao de pagto                        ³
				//³ Zera desconto,					                     ³
				//³ Zera as variaveis que indicam fator de financiamento ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				//se for desconto no total por forma de pagamento (Regra de Desconto Varejo) nao zera as variaveis de desconto
				If lLjGetDFP .AND. LjGetDesFP(3)
					LjValidPer(3)

				ElseIf   lLjGetDFP .AND. !LjGetDesFP(3)
                    //Volta o Valor do Desconto concebido pela forma
					Lj7T_DescV( 2, nValDescAnt)
					LjValidPer(1)
				EndIf

				LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
							Lj7T_DescV(2)	, Lj7T_Total(2)	)

				// Add os pagamentos realizados para analisar regra de desconto
			    aTipoPagto := {}
			    If Len(aPgtos) > 0
			    	For nX := 1 To Len(aPgtos)
			    		AADD(aTipoPagto,{CTOD(" "),	aPgtos[nX][2],aPgtos[nX][3]})
			    	Next nX
			    EndIf
				AADD(aTipoPagto,{CTOD(" "),aParcelas[2],aParcelas[3],cRGAdmFin})

				//Apura o valor do desconto: Parcela (se Proporcional) ou SubTotal
				//Alterado para o valor do desconto ser proporcional ao valor pago, para o cálculo ficar semelhante ao valor porporcional
			    If  !(lLjGetDFP .AND. LjGetDesFP(3) )
					nValor := 	aParcelas[2]
                Else
                	nValor := Lj7T_Total(2)
                EndIf

				// Verifica regra de desconto , mas para recebimento não se aplica a regra de desconto varejo
				If !lRecebe
					nDesc := RGDesTol(	.T.				, nValor	, cCondPagto	, aTipoPagto, ;
										M->LQ_CLIENTE 	, M->LQ_LOJA 		, Lj7T_Total(2)	, cFormPagto, ;
										.T. )
				EndIf

				If nDesc > 0
					//se for desconto no total por forma de pagamento (Regra de Desconto Varejo) nao zera as variaveis de desconto
					If lLjGetDFP .AND. LjGetDesFP(3)
						LjValidPer(3)
					EndIf
					nDescRGAux := lj7Arred(2, 3,  ( nValor * nDesc) / 100 )
					Lj7T_DescV(2, nValDescAnt + nDescRGAux)
					LjValidPer(1)
					//se for Desc.Total com Forma de Pgto e Proporcional (Regra de Desconto Varejo), abate o valor da parcela
					If !(lLjGetDFP .AND. LjGetDesFP(3))
						aParcelas[2] -= nDescRGAux //valor do desconto
					EndIf
					LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
							Lj7T_DescV(2)	, Lj7T_Total(2)	)

					aDesconto := { 2, Lj7T_DescP(2), Lj7T_DescV(2) }
				EndIf
			EndIf
		Else

			nValor := Lj7T_Total( 2 ) - nVlrPago

			If lNovRegDesc .AND. ExistFunc("RGDesTol") .AND. ExistFunc("CalPerc")

				//se for Desc. Total c/ Forma de Pgto(Regra de Desconto Varejo) nao zera as variaveis de desconto
				If lLjGetDFP .AND. ( LjGetDesFP(3)) .AND. nTipo <> 2
				    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Na troca da condicao de pagto                        ³
					//³ Zera desconto,					                      ³
					//³ Zera as variaveis que indicam fator de financiamento ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					LjValidPer(3)
				EndIf
				nValDescAnt :=   Lj7T_DescV(2)
				If nValDescAnt == 0 .AND. (nValDescAnt <> (Lj7T_SubTotal(2) - Lj7T_Total(2) ) )
					nValDescAnt :=   Lj7T_SubTotal(2) - Lj7T_Total(2)
					If nValDescAnt < 0
						nValDescAnt := 0
					EndIf
					Lj7T_DescV( 2, nValDescAnt)
				EndIf
				// Add os pagamentos realizados para analisar regra de desconto
			    aTipoPagto := {}
			    If Len(aPgtos) > 0
			    	For nX := 1 To Len(aPgtos)
			    		AADD(aTipoPagto,{CTOD(" "),	aPgtos[nX][2],aPgtos[nX][3]})
			    	Next nX
			    EndIf
				AADD(aTipoPagto,{CTOD(" "),nValor,cCondicao,cRGAdmFin})

				// Verifica regra de desconto , mas para recebimento não se aplica a regra de desconto varejo
				If !lRecebe
					nDesc := RGDesTol(	.T.				,nValor		, cCondPagto	, aTipoPagto,;
										M->LQ_CLIENTE 	,M->LQ_LOJA , Lj7T_Total(2)	, cFormPagto,;
										.T. )
				EndIf

				If nDesc > 0

					nDescRGAux :=  Lj7Arred(2, 3, ((nDesc / 100) * Lj7T_Total(2)) ) 				//Valor do desconto a ser aplicado (regra de desconto)
					nPercRGAux := ( nDescRGAux / LJ7T_SubTotal(2)  ) * 100 	//Percentual do desconto sobre o total bruto

					Lj7T_DescV( 2, nValDescAnt + nDescRGAux )
					LjValidPer(1)
					nValor := (nValor - nDescRGAux)



				EndIf

			EndIf
			
			LjGrvLog( NIL, "Browse com Parcelas - Antes de AltPgt 2 - aParcelas", aParcelas)
		    aParcelas := Lj7AltPgt(	Nil													,;
		   							{	dDataBase										,;
		   								nValor											,;
		   								cCondicao										,;
		   								.F.												,;
		   																				,;
		   								SuperGetMV("MV_MOEDA"+LTrim(Str(nMoedaCor)))	,;
		   								dDataBase	}										,;
										lAtuCond 											,;
										lTefPendCS)
			LjGrvLog( NIL, "Browse com Parcelas - Depois de AltPgt 2 - aParcelas", aParcelas)


			If lNovRegDesc .AND. ExistFunc("RGDesTol") .AND. ExistFunc("CalPerc")  .AND. Len(aParcelas) == 0 .and. nDesc > 0
			    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ No cancelamento da condicao de pagto                        ³
				//³ Zera desconto,					                     ³
				//³ Zera as variaveis que indicam fator de financiamento ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				//se for desconto no total por forma de pagamento (Regra de Desconto Varejo) nao zera as variaveis de desconto
				If lLjGetDFP .AND. LjGetDesFP(3)
					LjValidPer(3)

				ElseIf   lLjGetDFP .AND. !LjGetDesFP(3)
                    //Volta o Valor do Desconto concebido pela forma
					Lj7T_DescV( 2, nValDescAnt)
					LjValidPer(1)
				EndIf
				LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
							Lj7T_DescV(2)	, Lj7T_Total(2)	)
			EndIf


			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Recalcula regra de desconto pois o valor pode ser  ³
			//³proporcional ao pagamento alterado                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
  			If lNovRegDesc .AND. ExistFunc("RGDesTol") .AND. ExistFunc("CalPerc")  .AND.  Len(aParcelas) > 0   .AND. ;
				aParcelas[2] <  (Lj7T_Total( 2 ) - nVlrPago)

			    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Na troca da condicao de pagto                        ³
				//³ Zera desconto,					                     ³
				//³ Zera as variaveis que indicam fator de financiamento ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				LjValidPer(3)


				// Add os pagamentos realizados para analisar regra de desconto
			    aTipoPagto := {}
			    If Len(aPgtos) > 0
			    	For nX := 1 To Len(aPgtos)
			    		AADD(aTipoPagto,{CTOD(" "),	aPgtos[nX][2],aPgtos[nX][3]})
			    	Next nX
			    EndIf
				AADD(aTipoPagto,{CTOD(" "),aParcelas[2],aParcelas[3],cRGAdmFin})

				// Verifica regra de desconto , mas para recebimento não se aplica a regra de desconto varejo
				If !lRecebe
					nDesc := RGDesTol(	.T.				, Lj7T_Total( 2 )	, cCondPagto	, aTipoPagto, ;
										M->LQ_CLIENTE 	, M->LQ_LOJA 		, Lj7T_Total(2)	, cFormPagto)
				EndIf

				If nDesc > 0
					//se for desconto no total por forma de pagamento (Regra de Desconto Varejo) nao zera as variaveis de desconto
					If lLjGetDFP .AND. LjGetDesFP(3)
						LjValidPer(3)
					EndIf

					nValor := Lj7T_Total( 2 )
					nDescRGAux :=   lj7Arred(2, 3, (Lj7T_SubTotal(2) * nDesc) / 100)
					Lj7T_DescV( 2, nDescRGAux  )
					LjValidPer(1)
					nDescRGAux :=  lj7Arred(2, 3,  ((nDesc / 100) * nValor) )
					nValor := (nValor - nDescRGAux )   - nVlrPago

					//se for Desc.Total com Forma de Pgto e Proporcional (Regra de Desconto Varejo)
					If !(lLjGetDFP .AND. ( LjGetDesFP(3)))
						aParcelas[2] -= aDesconto[3] //valor do desconto
					EndIf


					LjSetLj7T(	1,	M->LQ_NUM	, Lj7T_SubTotal(2), Lj7T_DescP(2),;
							Lj7T_DescV(2)	, Lj7T_Total(2)	)
				EndIf
			EndIf

		EndIf

		If Len(aParcelas) > 0
			If cPaisLoc == "BRA"
				nVlrParc  := aParcelas[2]
				nValMoed1 := 0
			Else
				nVlrParc  := Round(xMoeda(aParcelas[2],aParcelas[5],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)
				nValMoed1 := Round(xMoeda(aParcelas[2],aParcelas[5],1,dDatabase,nDecimais+1,,),nDecimais)
			EndIf

			//Em ambiente PAF-ECF nao é permitido troco em cartão , a nao ser para Santa Catarina
			If	lHomolPaf .AND. lLjNfPafEcf .AND. !LJAnalisaLeg(63)[1] .AND. ;
				((nVlrPago + nVlrParc) > Lj7T_Total(2)) .AND. (AllTrim(aParcelas[3]) $ _FORMATEF)

				 If !lAutoExB
				 	MsgAlert(STR0197) //" Em ambiente PAF-ECF Troco em cartão não é habilitado "
				 Else
				 	ConOut(STR0197) //" Em ambiente PAF-ECF Troco em cartão não é habilitado "
				 EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//|	A mensagem abaixo so sera apresentada caso o sistema nao	|
			//|	esteja utilizando o troco para qualquer numerario           |
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			ElseIf (cPaisLoc == "BRA" .OR. !SuperGetMV("MV_LJTRLOC")) .AND. ((nVlrPago + nVlrParc) > Lj7T_Total( 2 )) .AND. !(aParcelas[3] $ cFormVale .OR. IsMoney(aParcelas[3])) .AND. ( SL1->( FieldPos( "L1_TROCO1" ) ) <= 0 .OR. !GetNewPar( "MV_LJTROCO", .F. ) )
				If !lAutoExB
					MsgStop(STR0044) //"Foi ultrapassado o valor total da venda. Só será permitida a inclusão de numerário em Dinheiro"
				Else
					ConOut(STR0044) //"Foi ultrapassado o valor total da venda. Só será permitida a inclusão de numerário em Dinheiro"
				EndIf
			Else
				nValAbISS := MaFisRet(,'NF_VALISS')

				If (Len(aPgtos) == 1 .AND. nVlrPago == 0) .OR. (Len(aPgtos) == 1 .AND. nVlrPago == (nNCCUsada + LJPCCRet() + If(LjxDAbISS(cCondPagto,cFormPagto,nValAbISS), nValAbISS, 0 ) ))
					aPgtos := {}
				EndIf
				
				LjGrvLog( NIL, "Browse com Parcelas - Preenchimento de aPgtos", aPgtos)
				
				If AllTrim(aParcelas[3]) $ _FORMATEF .AND. !Empty(aParcelas[4])
					aAdd( aPgtos, { aParcelas[1],;
									aParcelas[2],;
									aParcelas[3],;
									{},;
									NIL,;
					      			If(cPaisLoc <> "BRA" ,aParcelas[5], 1),;
					      			If(cPaisLoc<>"BRA",aParcelas[6],NIL), ;
					      			AllTrim(aParcelas[4]),;
					      			If(cPaisLoc <> "BRA", AllTrim(aParcelas[7]),NIL ),;
					      			nValMoed1,;
					      			0	} )
				ElseIf cPaisLoc == "ARG" .AND. AllTrim(aParcelas[3]) $ "CH" .AND. !Empty(aParcelas[7])
					aAdd( aPgtos, { aParcelas[1],;
									aParcelas[2],;
									aParcelas[3],;
									{},;
									NIL,;
					      			If(cPaisLoc<> "BRA" ,aParcelas[5], 1),;
					      			If(cPaisLoc<>"BRA",aParcelas[6],NIL), ;
					      			AllTrim(aParcelas[4]),;
					      			If(cPaisLoc <> "BRA", AllTrim(aParcelas[7]),NIL ),;
					      			nValMoed1,;
					      			0	} )
				Else
					nPosForma := aScan( aPgtos, {|x| Dtos(x[1])+AllTrim(x[3])+AllTrim(x[4]) == Dtos(aParcelas[1])+AllTrim(aParcelas[3])+AllTrim(aParcelas[4]) } )
					If nPosForma > 0
						aPgtos[nPosForma][2]	+= aParcelas[2]
						aPgtos[nPosForma][10]	+= nValMoed1
					Else
						aAdd( aPgtos, { aParcelas[1],;
									 	aParcelas[2],;
									 	aParcelas[3],;
									 	{},;
									 	NIL,;
						      			If(cPaisLoc<>"BRA",aParcelas[5],1),;
						      			If(cPaisLoc<>"BRA",aParcelas[6],NIL), ;
						      			AllTrim(aParcelas[4]),;
						      			If(cPaisLoc<>"BRA",AllTrim(aParcelas[7]),NIL),;
						      			nValMoed1,;
						      			0	} )
					EndIf
				EndIf
				
				LjGrvLog( NIL, "Browse com Parcelas - Conteudo de aPgtos", aPgtos)
			EndIf
		EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Atraves dos novos dados inseridos na tela de forma de pagamento         ³
	//³sera efetuado um tratamento especifico para cartoes de credito ou debito³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ElseIf nTipo == 3 .AND. AllTrim(cCondicao) == "CN"

		M->LQ_JUROS 	:= 0
		M->LQ_TIPOJUR 	:= 0
		LjGrvLog( NIL, "Browse com Parcelas - Antes de AltPgt - aRetPgto", aRetPgto)
		aRetPgto  := Lj7CalcPgt( ( nFormValor	- LJPCCRet()),;  //01 Valor a ser parcelado
									cCondicao	,;  	//02 Condicao - "CN" ou o Codigo da condicao de pagamento
									aCondNeg	,;		//03 Array contendo os dados da condicao negociada
									0			,;		//04 Valor que devera ser somado ao total da venda
									Nil			,;		//05 Percentual de acrescimo na venda (Localizacoes)
									Nil			,;		//06 Percentual de desconto financeiro (Localizacoes)
									Nil			,;		//07 Moeda da venda (Localizacoes)
									nValICMSSol	,;		//08 ICMS Solidario
									Nil			,;		//09 Dia Fixo
									Nil			,;		//10 Moeda Corrente
									Nil			,;		//11 Casas Decimais
									@nVlrAcrsFi	,;		//12 Valor do Acrescimo sobre o valor Financiado
		                            Nil         ,;
		                            Nil         ,;
		                            @nDiferenca ,;       //15 retorna o total de juros
									Nil			,;
									Nil			,;
									nValIpi)
		LjGrvLog( NIL, "Browse com Parcelas - Antes de AltPgt - aRetPgto", aRetPgto)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Faz o acerto do total na tela de Venda e nas parcelas                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Len(aRetPgto) > 0
			nVlrAux := 0
			For nX := 1 to Len(aPgtos)
				nVlrAux += aPgtos[nX][2]
			Next nX
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Se nao existirem informacoes na aPgtos zerar para adicionar as parcelas³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nVlrAux == 0
				aPgtos := {}
			EndIf

			For nX := 1 To Len(aRetPgto)
				aAdd( aPgtos, { aRetPgto[nX][1],;
				 				aRetPgto[nX][2],;
				 				cFormTroca ,;
				 				{},;
				 				NIL,;
				 				1,;
				 				NIL,;
				 				cFormaId,;
				 				" ",;
				 				0 } )
				nVlrAux += aRetPgto[nX][2]
			Next nX
			
			LjGrvLog( NIL, "Browse com Parcelas - aRetPgto > 0 - Conteudo de aPgtos", aPgtos)
			
			Lj7T_Total(2)
		EndIf

    ElseIf nTipo == 2 .AND. AllTrim(cCondicao) == "CO"
	//Tratamento para adicionar a forma de pagamento resgatada do PBM Funcional Card
       aPgtos := {}
       
       aAdd( aPgtos, { 	dDataBase,;
                      	nFormValor,;
                        cCondicao ,;
                        {},;
                        NIL,;
                        1,;
                        NIL,;
                        cFormaId,;
                        " ",;
                        0 ,;
                        0 } )
                        
        LjGrvLog( NIL, "Browse com Parcelas - nTipo com 2 e CO - Conteudo de aPgtos", aPgtos)
        
        Lj7T_Total(2)

	Else
	    //Necessario atualizar valores somente quando ExecAuto, utilizada na gravacao da Venda NFC-e
		If lAutoExB .AND. !lIntegDef
			nValor := Lj7T_Total( 2 )
			Lj7AltPgt(	Nil,{	dDataBase										,;
		   						nValor											,;
		   						cCondicao										,;
		   						.F.												,;
		   																		,;
   								SuperGetMV("MV_MOEDA"+LTrim(Str(nMoedaCor)))	,;
   								dDataBase	}									,;
								lAtuCond 										,;
								lTefPendCS)
		EndIf


		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Atribui os valores ref. ao calculo de juros                  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If AllTrim(cCondicao) == "CN"

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Identifica que foi a escolha de uma NCC³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !Empty(aCondNeg)
				M->LQ_JUROS 	:= aCondNeg[4]
				M->LQ_TIPOJUR 	:= If(ValType(aCondNeg[1])=="C",Val(Substr(aCondNeg[1],1,1)),aCondNeg[1])
			EndIf
		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Atribui os juros somente quando nao usou fator financ.  ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If (M->LQ_FATOR == 0) .AND. !Empty(cCondicao)
				M->LQ_JUROS 	:= Posicione("SE4",1,xFilial("SE4")+cCondicao,"E4_ACRSFIN")
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Quando for calculado via SE4 (formas de pagamento) sera sempre Juros Simples³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				M->LQ_TIPOJUR 	:= If(M->LQ_JUROS>0,1,0)
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Chama a funcao para calculo das parcelas, e tira o frete e a NCC Usada   ³
		//³ para nao entrar no calculo de juros                                      ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

		If LJ220AbISS(cCondPagto,cFormPagto,MaFisRet(,'NF_VALISS'))
		   nValAbISS := MaFisRet(,'NF_VALISS')
		EndIf
		nVlrSub  := LJ7T_SubTotal(2)
		If nNCCUsada - nVlrSub > 0
		   nSobraNCC := nVlrSub
		Else
		   nSobraNCC := nNCCUsada
		EndIf

		If cPaisLoc == "BRA"

			If !lRecebe .And. MaFisFound("NF")
				nValICMSSol := Lj7IcmsSol()
			Else
				nValICMSSol := 0
			EndIf

			//Verifica se houve alguma alteracao nos valores de frete, despesa ou seguro
			lFreteAlt := GetFretAlt()

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Na finalizacao do orcamento considerar o que foi gravado no L4. ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nOpc >= 0 .OR. lAtuPgto
                
                nVlrParcela := nVlrSub - LJ7T_DescV( 2 ) - nSobraNCC
                If nVlrParcela < 0
                    nVlrParcela := 0
                EndIf
                
			  	nValFrete   := Lj7CalcFrete( Nil , If(MaFisFound("NF"),MaFisRet(,"NF_VALSOL")>0,.T.), @nIcmSolDif )
	    		lCalcFrete	:= .F.
				nVlrSoma    := nValFrete

			    If nNCCUsada >= (nVlrSub + nValFrete) .OR. nNCCUsada >= Lj7T_total(2)
			       nVlrSoma  := 0
			    ElseIf (nNCCUsada - nVlrSub)  >  0 .AND. nVlrSoma <> 0
				    nExcedent := nNCCUsada - nVlrSub
				    If nExcedent <= nVlrSoma
				    	nVlrSoma -= nExcedent
				    Else
				    	nExcedent -= nVlrSoma
				    	nVlrSoma  := nExcedent
				    EndIf
                ElseIf nNCCUsada >  0 .AND. nValFrete > 0 
                   nVlrParcela += nValFrete                   
			    EndIf

  				If nModulo == 12
  					If nValFrete > 0  .AND. Lj7T_DescV(2) > 0 .AND. nNccUsada > 0 .AND. nNccUsada >= nVlrSub
  						nVlrSoma -= LJ7T_DescV( 2 )
  					EndIf
  				EndIf

                If nVlrParcela == 0
                    nVlrSoma := 0   //Se nao tiver parcela , nao considera o frete , pois nao deve ter apgtos
                EndIf
				nDescFin := 0
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Na finalizacao do orcamento verificar se o SL4 esta diferente do Valor das parcelas ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If cCondicao <> "CN"
					DbSelectArea( "SE4" )
					SE4->( DbSetOrder(1) )	//E4_FILIAL+E4_CODIGO
					If SE4->( DbSeek(xFilial("SE4") + cCondicao) )
						nVlrAux		:= NoRound( ( nVlrParcela * ( 1 + ( SE4->E4_ACRSFIN / 100 ) ) ) , nDecimais )
						nValorAcrs 	:= nVlrAux - nVlrParcela
						If ExistFunc("LJ7E4DSCFI")	//LOJXFUNC
							nValDscFin := LJ7E4DscFi(nVlrParcela,nOpc,lAltCond,1) //Verifica se SE4->E4_DESCFIN > 0
							nDescFin := nVlrParcela - nValDscFin
							If (nDescFin > 0) .AND. !(nMvLjTpDes = 2 .AND. !lFtvdVer12)
								//Na função Lj7CalcPgt() do LojxfunC(), só recalculava se nMvLjTpDes = 2 e !lFtvdVer12
								//Preciso obrigatoriamente desta linha abaixo, pois sem alterar qualquer forma de pagamento, ao salvar como F5,
								//aparecerá a mensagem abaixo e não irá finalizar:
								//"O total de parcelas para pagamento é menor que o valor total da venda".
								//"Total das parcelas - Total da Venda: R$ x.xx"
								Lj7T_Total( 2, Lj7T_SubTotal(2) - Lj7T_DescV(2) + Lj7CalcFrete() - nDescFin )
							EndIf
						EndIf
					EndIf
				EndIf

                //Caso tenha MultNegociacao e existir diferenca entre o Valor Pago e o Valor de Parcelas
				//essa diferenca eh o acrescimo do cartao de credito que deve ser apresentado no cupom.
				If lMultNeg .And. ( lLjIcmJr .And. cPaisLoc == "BRA" ) .and. (SL1->(ColumnPos("L1_CODMNEG")) > 0 .And. !Empty(SL1->L1_CODMNEG) )
					nMNCC := aScan(aPgtos,{|x| AllTrim(Upper(x[3])) == "CC"})
					If nMNCC > 0
						nValorAcrs += nVlrPago - nVlrParcela
					EndIf
				EndIf
				
				//deve considerar o valor do acrescimo e do frete para impedir alteração da forma de pagto
				If nOpc == 4 
					If nVlrParcela <> ((nVlrPago+nDescFin) - (nValorAcrs+nValFrete))
						lAltCond := .T.
						LjGrvLog( NIL, " lAltCond recebe .T. - diferença entre valor pago e as parcelas")
					EndIf
					
					If lAltCond
						// Caso na finalizacao do orcamento seja aplicado o valor de uma NCC
						// que nao foi previamente selecionada na gravacao do orcamento,
						// sera considerada a condicao de pagamento padrao para o recalculo.
				    	If Empty(cCondicao) .AND. (SL1->L1_CREDITO == 0) .And. nNCCUsada > 0  
				    		cCondicao := cCondPad 			     
				    		LjGrvLog( NIL, " Valor de NCC Setado, Não Tem Credito e Condicao de Pagamento em Branco - recebe condição padrão - cCondPad [" + cCondPad + "]")
						EndIf
					EndIf
			    EndIf			    
			    
				//³So vai recalcular a Cond de Pagto se ela for alterada ou se o usuario ³
				//³selecionar uma NCC,isso para preservar a Cond selecionad no Orcamento ³
			    If !lIntegDef .And. (lAltCond .OR. nOpc <> 4 .OR. ( nNCCUsada > 0 ) .OR. lDesSelNCC .OR. lFreteAlt)
			    	LjGrvLog( NIL, "Browse com Parcelas - {lAbatPNCC,nVlrParcela,cCondicao,aCondNeg,nVlrSoma,nOpc,nValFrete}",;
			    	 				{lAbatPNCC,nVlrParcela,cCondicao,aCondNeg,nVlrSoma,nOpc,nValFrete})
			    	 							    
			    	LjGrvLog( NIL, "Browse com Parcelas - Preservação da cond com NCC- Antes de CalcPgt", aRetPgto)			    	
			  		aRetPgto    := Lj7CalcPgt( IIF(lAbatPNCC, nVlrParcela + nNCCUsada ,Iif (nNCCUsada > 0,nVlrParcela - nValFrete, nVlrParcela)) 	,;
			  		 							cCondicao 	, aCondNeg	, nVlrSoma	   	,;
				                          		NIL    		, NIL		, NIL			, nValICMSSol	,;
				                          		NIL    		, NIL		, NIL			, @nVlrAcrsFi	,;
       				                            Nil         , Nil		, @nDiferenca	, nOpc			,;
       				                            lAltCond	, nValIpi 	)
       				LjGrvLog( NIL, "Browse com Parcelas - Preservação da cond com NCC- Depois de CalcPgt", aRetPgto)
					
					If lAbatPNCC
	       				If nNCCUsada >= ARETPGTO[1][2]
	       					ARETPGTO[1][2] = 0
	       				Else
	       					ARETPGTO[1][2] -= nNCCUsada
	       				EndIf
	       			EndIf

	   			   	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Abate valor de ISS ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If LJ220AbISS(cCondPagto,cFormPagto,MaFisRet(,'NF_VALISS')) .AND. nValAbISS > 0
						nValRetISS :=  nValAbISS
						nVlrParcela -= nValAbISS

						//Abate o valor na primeira parcela
						If !lpTPAbISS .AND. Len(aRetPgto) >= 1 .AND. ( nValAbISS < aRetPgto[1][2] )
							aRetPgto[1][2]-= nValAbISS
						Else
							//Realiza novamente o calculo das parcelas
							LjGrvLog( NIL, "Browse com Parcelas - Preservação da cond com NCC- Antes de CalcPgt - ISS", aRetPgto)
					  		aRetPgto    := Lj7CalcPgt( nVlrParcela 	, cCondicao , aCondNeg     , nVlrSoma  ,;
						                          		NIL    		,   NIL     ,   NIL        , nValICMSSol,;
						                          		NIL    		,   NIL     ,   NIL        , @nVlrAcrsFi,;
		       				                            Nil         ,	Nil     ,   @nDiferenca, nOpc	,;
		       				                            lAltCond, nValIpi )
		       				LjGrvLog( NIL, "Browse com Parcelas - Preservação da cond com NCC- Depois de CalcPgt - ISS", aRetPgto)
						EndIf
                    Else
                    	nValRetISS := 0			//Limpa variavel static de retencao de ISS
                    EndIf

				   	lDesSelNCC 	:= .F.
					//Atribuindo valor falso a variavel static lFreteAlt do fonte LOJA701A.PRW
					SetFretAlt(.F.)
				EndIf
			    lAtuPgto := .F.
			EndIf
		Else
			If nOpc <> 4 .OR. lAtuPgto
			    nVlrParcela := Lj7T_SubTotal(2) - nSobraNCC
			    LjGrvLog( NIL, "Browse com Parcelas - nOpc <> 4 ou lAtuPgto - Antes de CalcPgt", aRetPgto)
				aRetPgto := Lj7CalcPgt( nVlrParcela , cCondicao	, aCondNeg 	, Lj7CalcFrete(),;
				                      	NIL     	, NIL    	, nMoedaCor	, NIL			,;
				                      	NIL    		, nMoedaCor	, NIL    	, @nVlrAcrsFi	,;
       				                    Nil         , Nil       , @nDiferenca, NIL, NIL, nValIpi )
       	        LjGrvLog( NIL, "Browse com Parcelas - nOpc <> 4 ou lAtuPgto - Antes de CalcPgt", aRetPgto)       				                    
				lAtuPgto := .F.
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Existindo informacoes sobre a forma de pagto e for config. que   ³
		//³  a nova regra esta ativa, validacao das informacoes apresentadas³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Len(aRetPgto) > 0 .And. lNovRegDesc .AND. !lRecebe  // Verifica regra de desconto , mas para recebimento não se aplica a regra de desconto varejo
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Valida as informacoes e retorna percentual de desconto a ser aplicada    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If ExistFunc("RGDesTol") //Loja 3026
				If ValType(cFormPagto) == "U"
					nPosMoney := Ascan(aRetPgto, {|x| IsMoney(x[3])} )
					If nPosMoney > 0
						cFormPagto := aRetPgto[nPosMoney][3]
					EndIf
				EndIf
				//Zera o array aTipoPagto
				aTipoPagto := {}
				aEval(aRetPgto, {|aRet|  aAdd(aTipoPagto, {aRet[1],aRet[2],aRet[3], cRGAdmFin }) } )
				nPerDesc := RGDesTol(.T., Lj7T_SubTotal(2), cCondPagto, aTipoPagto,M->LQ_CLIENTE ,M->LQ_LOJA,Lj7T_SubTotal(2),cFormPagto,.T.)
				//Zera o array aTipoPagto
				aTipoPagto := {}
			EndIf

			If (nPerDesc > 0) .OR. (nPerRDAnt <> nPerDesc) .OR. ( lNovRegDesc .AND. !Empty(nPerRDAnt) )

				If nPerDesc == 0
					//Restaura os valores originais do array aTotais, antes de atribuir descontos associado a forma de pagamento. (Usado somente quando for a nova regra de desconto varejo)
					LjRetLj7T()
				Else

					nPerRDAnt := nPerDesc

					LjValidPer(3)

					nVlrTotAux := Lj7T_Total( 2 )

					nDescRGAux := Lj7Arred(2,3, (nVlrTotAux / 100) * nPerDesc )

					aDesconto := { 	2,;
		   							CalPerc( Lj7T_Total( 2 ), 	 Lj7T_Total(2) - ((nVlrTotAux / 100) * nPerDesc ) ) ,;
									nDescRGAux}

					Lj7T_DescP( 2, aDesconto[2] )
					lVldUser := LjValidPer(2)

					// Caso não permita efetuar o desconto deve zerar os descontos
					If lVldUser
						nVlrTotAux := (nVlrTotAux - nDescRGAux)
					Else
						Lj7T_DescV( 2, 0 )
					    Lj7T_DescP( 2, 0 )
					EndIf
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Chama da funcao de carregar as forma de pagto na tela, porem ja com desc.³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				aRetPgto := Lj7CalcPgt( nVlrTotAux 		, cCondicao	, aCondNeg 	, Lj7CalcFrete(),;
				                      	NIL     		, NIL    	, nMoedaCor	, NIL        	,;
				                      	NIL    	    	, nMoedaCor	, NIL    	, @nVlrAcrsFi	,;
       				                    Nil             , Nil       , @nDiferenca, NIL, NIL, nValIpi )
			EndIf

		EndIf

		If lMvLjAltPG
	        If ValType(cVldLQCondPg) == "C"
	            lVldUserCpg := &(cWhenQCondPg) .AND. &(cVldLQCondPg)
	            LjGrvLog( NIL, " Browse com Parcelas -  Validação de Cond via usuario", lVldUserCpg)
	        EndIf
	    Else
	    	lVldUserCpg := .F.
	    	LjGrvLog( NIL, " Configuração de Usuário: X3_WHEN e X3_VLDUSER no campo LQ_CONDPG não será considerada pois o parâmetro MV_LJALTPG está ativo")
	    	LjGrvLog( NIL, " Parâmetro MV_LJALTPG configurado com .F. - impedindo alteração da condição de pagamento")
	    EndIf
        
        If lVldUserCpg
            //Valida Condicao de Pagto
            If !LJ7VldCond(M->LQ_CONDPG, @cDescCondPg, @oDescCondPg, @oPgtos, Nil, nOpc, @nVlrAcrsFi)
                Lj7ZeraPgtos()
                lContinua 	:= .F.
                LjGrvLog( NIL, " Browse com Parcelas -  Zerou Pagamentos - lVldUserCpg", lVldUserCpg)
            EndIf
        EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Faz o acerto do total na tela de Venda e nas parcelas                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lContinua
			If Len(aRetPgto) > 0
				
				LjGrvLog( NIL, "Browse com Parcelas - lContinua e aRetPgto preenchido", aRetPgto)
				
				If nNCCUsada < Lj7T_Total(2)
					nVlrAux := 0
				EndIf
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Zera o array aPgtos para gravar o novo calculo³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				aPgtos := {}
				For nX := 1 to Len(aRetPgto)
					aRetPgto[nX][2] := Round( aRetPgto[nX][2], nDecimais )
					nValMoed1 := Round(xMoeda(aRetPgto[nX][2],aRetPgto[nX][_MOEDA],1,dDatabase,nDecimais+1,,),nDecimais)
					aAdd( aPgtos, {	aRetPgto[nX][1],;
									aRetPgto[nX][2],;
									aRetPgto[nx][3],;
									{},;
									NIL,;
					                If(cPaisLoc<>"BRA",aRetPgto[nX][_MOEDA],1),;
					                If(cPaisLoc<>"BRA",aRetPgto[nX][_EMISSAO],NIL),;
					                If(AllTrim(aRetPgto[nx][3])$_FORMATEF .AND. lTefMult ,"1",Space(01)),;
					                If(AllTrim(aRetPgto[nx][3])$"CH;FI", aRetPgto[nx][8], Space(01)),;
					                nValMoed1,;
					                0 } )
					nVlrAux += aRetPgto[nX][2]
				Next nX
				
				LjGrvLog( NIL, "Browse com Parcelas - lContinua e aRetPgto preenchido - aPgtos", aPgtos)
				
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Faz o recalculo do vencimento das parcelas no caso de uso de Dia Fixo    ³
				//³ para vencimento das parcelas.                                            ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lDiaFixo
					dDataHj := dDataBase
					dDataBase := aCondNeg[2]
					aE4 := {,Str(aCondNeg[5])+',0,'+Str(aCondNeg[6]), "3"," "," "," "}
					aParcDiaFixo := AvalCond( Lj7T_Subtotal( 2 ) , , , , nAux , ,aE4, nAux ,aE4,,{0,aCondNeg[6]} )
					For nX := 1 to Len(aPgtos)
						aPgtos[nX][1] := aParcDiaFixo[nX][1]
						If Month(aPgtos[nX][1]) == 2 .AND. aCondNeg[6] == 31 .AND. !AnoBissexto( Year(aPgtos[nX][1]) )
							aPgtos[nX][1] := Ctod('01/03/'+ Str(Year(aPgtos[nX][1])))
						EndIf
					Next nX
					dDataBase := dDataHj
				EndIf

				nDifNCCTot := nSobraNCC
				If nValFrete <> 0
				    If nNCCUsada >= (nVlrSub + nValFrete)
						nDifNCCTot := nVlrSub + nValFrete
				    Else
				    	nDifNCCTot := nNCCUsada
				    EndIf
				EndIf

                //Rodape Total da Venda
                Lj7T_Total( 2, ( nVlrAux + nDifNCCTot + iIf( LJ220AbISS(Nil, Nil, MaFisRet(,'NF_VALISS')), MaFisRet(,'NF_VALISS') , 0) ))

			Else
				nVlrAux := 0
				Lj7AjustaTroco(Nil,cCondPagto,cFormPagto)
				For nX := 1 to Len(aPgtos)
					nVlrAux += Round(xMoeda(aPgtos[nX, 2], aPgtos[nX, _MOEDA], nMoedaCor, dDatabase, ;
									   		 nDecimais + 1, NIL               , nTxMoeda), nDecimais)
				Next nX
				If cPaisLoc == "BRA"
					If nVlrPago > 0 .And. nNCCusada == 0
						nTroco := Lj7T_Troco(2)
					EndIf
				Else
					If SuperGetMV("MV_LJTRLOC",,.F.) .AND. nVlrPago > 0 .AND. nNCCusada == 0
						nTroco := Lj7T_Troco(2)
					EndIf
				EndIf

				nDifNCCTot := nSobraNCC
			    If nNCCUsada >= (nVlrSub + nValFrete)
					nDifNCCTot := nVlrSub + nValFrete
					lCalcFrete := .F.
			    Else                                // qdo a venda tem desconto e frete , o valor da ncc tem que ser integral e nao somente com o frete
			    	nDifNCCTot := nNCCUsada
			    EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Quando for realizada uma finalização de venda após a gravação de um         ³
				//³orçamento, e ao montar o Total da venda de acordo com as parcelas,          ³
				//³antes, verifica se o TOTAL DE PARCELAS é igual ao TOTAL DA VENDA            ³
				//³já definido na primeira tela da Venda Assistida.                            ³
				//³                                                                            ³
				//³Necessária essa alteração pois antes acontecia a seguinte situação:         ³
				//³- Finalizar a venda de um orçamento em aberto                               ³
				//³- Em pagamentos, zerar e escolher Dinheiro                                  ³
				//³- Digitar um valor INFERIOR ao total já estabelecido anteriormente          ³
				//³- Finalizar a venda                                                         ³
				//³- Verificar que a venda era executada. O correto era validar se o total     ³
				//³de parcelas está igual ou superior ao total da venda, para aí sim finalizar ³
				//³a venda.                                                                    ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If Lj7T_TotPar(2) == Lj7T_Total(2)
					Lj7T_Total( 2, ( nVlrAux + nDifNCCTot + IIf( LJ220AbISS(), MaFisRet(,'NF_VALISS') , 0 ) - nTroco ))
				EndIf

			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Alimenta o array de acrescimo. Avalia se o desconto foi concedido antes³
			//³ou depois do acrescimo.                                                ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If M->LQ_JUROS > 0

	            If nNCCUsada <= nVlrAux
	                If nDiferenca > 0      // se não vier nada calculado da função Lj7CalcPgt, não altera o acrescimo
					    aAcrescimo[1] := nNCCUsada + nDiferenca
	                EndIf
	            Else
	               If nDiferenca > 0
					    aAcrescimo[1] := nDiferenca
	                EndIf
	            EndIf

				aAcrescimo[2] := M->LQ_JUROS	// Percentual do acrescimo

			Else
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Valor do acrescimo³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				aAcrescimo[1] := 0
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Percentual do acrescimo³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				aAcrescimo[2] := 0
			EndIf
		EndIf

	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ A Forma $ sempre sera a primeira!!!  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (nPos:=AScan(aPgtos, {|x| AllTrim(x[3]) == AllTrim(cSimbMoeda)})) > 1
		AAdd(aPgtos, {})
		AIns(aPgtos, 1)
		nPos++
		aPgtos[1] := aPgtos[nPos]
		ADel(aPgtos, nPos)
		ASize(aPgtos, Len(aPgtos)-1)
	EndIf

	If lAtuList
		If !lAutoExB
			oPgtos:SetArray( aPgtos )
			oPgtos:Refresh()
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta o Valor das Parcelas e o Valor do Troco³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7AjustaTroco(Nil,cCondPagto,cFormPagto)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta os valores de PIS/COFINS caso Haja                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7PisCof(cCondPagto,cFormPagto)
	EndIf

	If lVisuSint
		aPgtosSint := Lj7MontPgt(aPgtos)
		If !lAutoExB
			oPgtosSint:SetArray( aPgtosSint )
			oPgtosSint:Refresh()
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Volta a variável lRgAcumul como era antes de entrar na RgDesTol() ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If FindFunction( "LJSETRACUMUL" )
		LjSetRAcumul( lRgAcumulAnt )
	EndIf

EndIf

If lLj7063
	LjGrvLog( NIL , "Antes da execução do P.E. LJ7063 - { nTipo, cCondicao, nOpc, lRecal } ", { nTipo, cCondicao, nOpc, lRecal })
	ExecBlock( "LJ7063",.F.,.F., { nTipo, cCondicao, nOpc, lRecal } )
	LjGrvLog( NIL , "Depois da execução do P.E. LJ7063 - { nTipo, cCondicao, nOpc, lRecal } ", { nTipo, cCondicao, nOpc, lRecal })
EndIf

Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7AltPgt ºAutor  ³ Vendas Clientes    º Data ³  13/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Monta a tela para alteracao dos dados das parcelas de pgto  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpU1 := Lj7AltPgt( ExpN1, ExpA1 )                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpN1 - Numero da linha do objeto oPgtos que esta sendo     º±±
±±º          ³        alterada.                                           º±±
±±º          ³ExpA1 - Array contendo os dados DEFAULT. Utilizado quando   º±±
±±º          ³        ExpN1 for Nil ou 0 (zero)                           º±±
±±º          ³ExpL1	- Define se mostra a tela de permissao para alterar   º±±
±±º          ³        parcelas                                            º±±
±±º          ³ExpL2	- Define se existe Tef Pendente						  º±±
±±º          ³ExpA2	- Contem os valores (subtotal,desconto em $e% e Total)º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpU1 - Se ExpN1 for 0 (zero) ou Nil:                       º±±
±±º          ³        A funcao retorna um array contendo:                 º±±
±±º          ³           [1] - Data                                       º±±
±±º          ³           [2] - Valor                                      º±±
±±º          ³           [3] - Forma de pagamento                         º±±
±±º          ³           [4] - Moeda(Localizacoes)                        º±±
±±º          ³           [5] - Data de Emissao(Localizacoes)              º±±
±±º          ³                                                            º±±
±±º          ³        Se for cancelada a janela e ExpN1 = 0 a funcao      º±±
±±º          ³        retornara um array vazio {}                         º±±
±±º          ³                                                            º±±
±±º          ³        Se ExpN1 for > 0 (zero)                             º±±
±±º          ³        A funcao nao retornara nada e irah alterar o objeto º±±
±±º          ³        oPgtos.                                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7AltPgt( nLinha		, aDados	, lSenha , lTefPendCS,;
					cRGAdmFin 	, aTefBKPCS	)
Local dData			:= Ctod(Space(8))
Local nValor		:= 0
Local nVlrPago 		:= 0
Local nX 			:= 0
Local nPos 			:= 0
Local nMoedaParc    := 1
Local nValMoed    := 0
Local nPosMoeda1    := 0
Local nPosParc      := 0
Local cForma 		:= Space(10)
Local cFormaRed		:= ""
Local cMvSimb1		:= SuperGetMV("MV_SIMB1")
Local cMoeda        := ""
Local cSimb         := ""
Local cFormaPgto    := ""
Local lConfirma 	:= .F.
Local lCheckPag		:= .F.
Local lValidaTudo	:= .F.
Local lLj7009		:= ExistBlock("LJ7009")
Local lDinheiro     := .F.
Local aFormas 		:= {}
Local aFormas2 		:= {}
Local aLj7009		:= {}
Local aValores      := {}
Local aBckPgtos     := AClone(aPgtos)
Local uRetorno
Local dEmissao      := Ctod(Space(8))
Local oDlgPgto
Local oData
Local oValor
Local oForma
Local oCheckPag
Local oEmissao
Local oMoeda
Local oParc
Local oCart
Local oCheque
Local nPosObj		:= IIF(IsBlind(),1,IIf(lVisuSint .AND. Type("oPgtosAna")=="O", oPgtosAna:nAt , oPgtos:nAt ))
Local cFormaId		:= If(lVisuSint,Space(TamSX3("L4_FORMAID")[1]),Space(01))			//Identificação do cartao
Local cChequeId		:= IIf(SL4->(FieldPos("L4_CHEQID"))>0,Space(TamSx3("L4_CHEQID")[1]),Space(1))			//Identificação do cheque
Local cFormaIdAnt	:= cFormaId
Local nParc			:= 1
Local cCodForma		:= Space(02)
Local nDiferenca    := 0
Local nRestDif      := 0
Local nFixo         := 0
Local nConta		:= 0												//Utilizada no for, para calculo dos valores restantes
Local nVlrTotal     := 0                        						//Valor total da venda
Local nDifArred     := 0                        						//Diferenca de arredondamento entre o total e as parcelas
Local nToler        := 0                        						//Tolerancia permitida na conversao de valores
Local cSimbMoeda	:= SuperGetMV("MV_SIMB"+Ltrim(Str(nMoedaCor)))
Local lContinua	    := .T.                     							// Controla se continua a operacao
Local xRet                                      						// Retorno do PE LJ7009
Local aParcEsp      := {}                      							// Parcelas devolvidas pelo PE LJ7009
Local lUsouFator	:= If(M->LQ_FATOR > 0, .T., .F.)					// Indica se esta usando fator financeiro
Local lTransCart	:= .T.												// Se esta trabalhando com transacao com cartao
Local cFormVale		:= IIf(SuperGetMV("MV_LJVALEP",,.F.),"VA|VP","VA")	// Utiliza Vale Presente
Local lRecPar		:= SuperGetMV("MV_LJRECPA",,.T.)                   // Recalcula valor das Parcelas
Local nTamL4Vlr		:= TamSX3("L4_VALOR")[1]                           // Tamanho do campo Valor
Local nTamL4VlrD	:= TamSX3("L4_VALOR")[2]                           // Casas Decimais do campo Valor
Local lAutoExB 		:= IsBlind()										// Verifica se a rotina sera executada via execauto ou nao
Local aFTVD7009		:= {}
Local lFTVD7009		:= ExistBlock("FTVD7009")
Local nPosAux 		:= 0
Local lAtuPf		:= (SuperGetMv("MV_LJATUPF",,"N") == "S")
Local cCondPgto		:= IIF(!Empty(cCondAntX), cCondAntX, SuperGetMV("MV_CONDPAD",, "001")) // Condicao de pagamento padrao
Local cBkpFrmTrc		:= "" //Backup da forma de pagto troco
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default nLinha 			:= 0
Default aDados			:= {}
Default lSenha			:= .T.												//Variavel utilizada para pedir senha de liberacao para alterar parcelas
Default lTefPendCS  	:= .F.
Default cRGAdmFin 		:= ""
Default aTefBKPCS		:= {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se a parcela for igual a de Financiamento e utilizar      ³
//³ Fator de multiplicacao, sai da tela. 					  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lUsouFator .AND. ( AllTrim(aPgtos[nLinha][3]) == "FI" )
	If !lAutoExB
		MsgInfo(STR0115)  //"Num financiamento com fator nao se permitira a alteracao da forma de pagamento. Para alterar, escolha outra Condicao de Pagamento."
	Else
		ConOut(STR0115)  //"Num financiamento com fator nao se permitira a alteracao da forma de pagamento. Para alterar, escolha outra Condicao de Pagamento."
	EndIf
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se Forma de Pagto Multi Negociacao, nao permite alteracao ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SLQ->(FieldPos("LQ_CODMNEG")) > 0 .And. !Empty(M->LQ_CODMNEG)
	If !lAutoExB
		MsgInfo(STR0200)  //"Não é permitida a alteração das formas de pagamento quando utilizado Multi Negociação."
	Else
		ConOut(STR0200)  //"Não é permitida a alteração das formas de pagamento quando utilizado Multi Negociação."
	EndIf

	uRetorno := {}

	Return uRetorno
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Prepara o array das formas de pagamento                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 to Len(aFormPgtos)
	If aFormPgtos[nX][1] <> "CN" .AND. !Empty(aFormPgtos[nX][1])
		aAdd( aFormas, Capital(aFormPgtos[nX][2]) )
		aAdd( aFormas2, AllTrim(aFormPgtos[nX][1]) )
	EndIf
Next nX

If nLinha > 0
	dData 	:= aPgtos[nLinha][1]
	nValor 	:= aPgtos[nLinha][2]
	nPos 	:= aScan(aFormPgtos, {|x| AllTrim(x[1])==AllTrim(aPgtos[nLinha][3])})
	If nPos > 0
		cForma 	  := Capital(aFormPgtos[nPos][2])
		cCodForma := AllTrim(aFormPgtos[nPos][1])
	Else
		cForma 		:= ""
		cCodForma 	:= Space(02)
	EndIf
    If SuperGetMV("MV_TEFMULT") .AND. lVisuSint
		cFormaID 	:= aPgtos[nLinha][8]
		cFormaIdAnt := cFormaID
	EndIf
	If cPaisLoc <> "BRA"
	   If SL4->(FieldPos("L4_VLMOED1")) > 0
		  nValMoed := aPgtos[nLinha][10]
	   EndIf
		If (cForma $ "CH") .AND. (SL4->(FieldPos("L4_CHEQID")) > 0)
			cChequeId	:= aPgtos[nLinha][9]
		EndIf
		nMoedaParc	:= aPgtos[nLinha][_MOEDA]
		cMoeda		:= SuperGetMV("MV_MOEDA"+Ltrim(Str(aPgtos[nLinha,_MOEDA])))
		dEmissao	:= aPgtos[nLinha][_EMISSAO]
	EndIf
Else
	dData 	:= If(!Empty(aDados).AND.aDados[1]<>Nil,aDados[1],dDataBase)
	nValor 	:= If(!Empty(aDados).AND.aDados[2]<>Nil,aDados[2],0)
	If !Empty(aDados) .AND. aDados[3] <>  Nil
		nPos 	:= aScan(aFormPgtos,{|x|AllTrim(Upper(x[1]))==AllTrim(Upper(aDados[3]))})
		If nPos > 0
			cForma 	  := Capital(aFormPgtos[nPos][2])
			cCodForma := AllTrim(aFormPgtos[nPos][1])
		Else
			cForma 		:= ""
			cCodForma 	:= Space(02)
		EndIf
	Else
		cForma 		:= ""
		cCodForma 	:= Space(02)
	EndIf
	If cPaisLoc <> "BRA"
       cMoeda 	:= If(!Empty(aDados) .AND. aDados[_MOEDA]<>Nil,aDados[_MOEDA],SuperGetMV("MV_MOEDA"+LTrim(Str(nMoedaCor))))
       Lj7FillPgto(cMoeda,@nMoedaParc,nLinha,nValor)
	   dEmissao := If(!Empty(aDados) .AND. aDados[_EMISSAO]<>Nil,aDados[_EMISSAO],dDataBase)
	EndIf
EndIf

While !lValidaTudo
	lConfirma := .F.

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se existe o P.E. Lj7009 alimenta o array que sera passado como        ³
	//³ parametro                                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lLj7009 .AND. !lFtvdVer12
		aAdd( aLj7009, { dData, nValor, cForma, lCheckPag, cFormaId } )
	EndIf

	If lFTVD7009 .AND. lFtvdVer12
		aAdd( aFTVD7009, { dData, nValor, cForma, lCheckPag, cFormaId } )
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria interface com o usuario                                          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc == "BRA"

		If !lAutoExB
			LJTELAALTPG(@oDlgPgto	, @oDlgVA		, @oData	, @oValor		, ;
					     @oForma	, @oCheckPag	, @oParc	, @oCart		, ;
					     Nil		, Nil 			, @dData	, @nValor		, ;
					     @aFormas	, aPgtos        , @nLinha	, @cCodForma	, ;
					     lVisuSint	, @cFormaId		, @cForma	, @nParc		, ;
					     aFormPgtos	, @lCheckPag	, @lConfirma, @dEmissao		, ;
					     1 			, Nil			, Nil		, Nil			, ;
					     Nil		, Nil			, lSenha	, lTefPendCS	,;
					     Nil		, Nil			, aTefBKPCS )

			If !Empty(cRGAdmFin)   .AND.  ( aScan( aAdmsFinRG, {|x| AllTrim(x[3])+AllTrim(x[1]) == AllTrim(cFormaIdAnt)+AllTrim(cCodForma) } )  = 0 )
				aAdd( aAdmsFinRG, {cCodForma, cRGAdmFin, cFormaId} )
			ElseIf cFormaIdAnt != cFormaId
				If ( nPosAux := aScan( aAdmsFinRG, {|x| AllTrim(x[3])+AllTrim(x[1]) == AllTrim(cFormaIdAnt)+AllTrim(cCodForma) } ) ) > 0
					aAdmsFinRG[nPosAux][3] := cFormaId
				EndIf
			EndIf

		EndIf
	Else
 		If (aMoeda == Nil)
          	aMoeda := {}
	  		For nX := 1	To MoedFin()
	        	If(!(Empty(SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))))))
	                AAdd(aMoeda,SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))))
	            Else
	            	Exit
	         	EndIf
	    	Next nX
	  	EndIf

	   	If nLinha > 0
	    	cFormaPgto  := AllTrim(aPgtos[nLinha,3])
	    ElseIf !Empty(aDados) .AND. aDados[3] <> Nil
	        cFormaPgto  := aDados[3]
	    Else
	        cFormaPgto  := ""
	    EndIf
	    If IsMoney(cFormaPgto)
			lDinheiro := .T.
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Posicao do simbolo da moeda 1 para ser usada de forma generica para todas as moedas³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		    nPosMoeda1 := Ascan(aFormPgtos,{|x|AllTrim(x[1]) == cMvSimb1})
	  	EndIf
	       nPosParc := Ascan(aFormPgtos,{|x|AllTrim(x[1]) == cFormaPgto})
		If lDinheiro .AND. nPosMoeda1 > 0
			cForma := Capital(aFormPgtos[nPosMoeda1,2])  //Para todas as moedas, mostra a descricao Dinheiro
	   	ElseIf nPosParc > 0 .AND. Empty(cForma)
		  	cForma := Capital(aFormPgtos[nPosParc,2])
	   	EndIf
        If !lAutoExB
			LJTELAALTPG( @oDlgPgto	, @oDlgVA		, @oData	, @oValor		, ;
					     @oForma	, @oCheckPag	, @oParc	, @oCart		, ;
					     oEmissao	, oPgtos		, @dData	, @nValor		, ;
					     @aFormas	, @aPgtos		, @nLinha	, @cCodForma	, ;
					     lVisuSint	, @cFormaId		, @cForma	, @nParc		, ;
					     aFormPgtos	, @lCheckPag	, @lConfirma, @dEmissao		, ;
					     2 			, @oMoeda    	, @cMoeda 	, @aMoeda 		, ;
					     @aValores 	, @nMoedaParc	, lSenha	, lTefPendCS	, ;
					     @oCheque	, @cChequeId	, aTefBKPCS )
		EndIf
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se existe o P.E. Lj7009 alimenta o array que sera passado como        ³
	//³ parametro                                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (lLj7009 .AND. lConfirma) .AND. !lFtvdVer12
		aAdd( aLj7009, { dData, nValor, cForma, lCheckPag, cFormaId } )
	EndIf

	If (lFTVD7009 .AND. lConfirma) .AND. lFtvdVer12
		aAdd( aFTVD7009, { dData, nValor, cForma, lCheckPag, cFormaId } )
	EndIf

	If lConfirma
		cFormaRed := aFormPgtos[aScan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})][1]
	    If SuperGetMV("MV_TEFMULT") .AND. lVisuSint .AND. cFormaRed $ _FORMATEF .AND. Empty(cFormaId)
	    	If !lAutoExB
				MsgAlert(STR0110,STR0001) //"Informe o ID do Cartão para a operação TEF.","Atenção"
			Else
				ConOut(STR0110) //"Informe o ID do Cartão para a operação TEF.","Atenção"
			EndIf
		ElseIf cPaisLoc == "ARG" .AND. (SL4->(FieldPos("L4_CHEQID")) > 0) .AND. cFormaRed $ "CH" .AND. Empty(cChequeId)
			If !lAutoExB
				MsgAlert(STR0174,STR0001) //"Informe o ID do Cheque.","Atenção"
			Else
				Conout(STR0174)
			Endif
		ElseIf !(cFormaRed == "VA" .OR. IsMoney(cFormaRed)) .OR. ((cFormaRed == "VA" .OR. IsMoney(cFormaRed)) .AND. (dData == dDatabase))
			lValidaTudo := .T.
		Else
			If !lAutoExB
				MsgStop( STR0047+cFormaRed+STR0048 ) //"Não é possível fazer um pagamento em "###" se o vencimento não for a vista."
			Else
				ConOut( STR0047 + cFormaRed + STR0048 ) //"Não é possível fazer um pagamento em "###" se o vencimento não for a vista."
			EndIf
		EndIf
	Else
		lValidaTudo := .T.
	EndIf

End

If lConfirma
	If lLj7009 .AND. !lFtvdVer12
		xRet  := ExecBlock("LJ7009",.F.,.F.,{aLj7009[1],aLj7009[2]})
		If ValType(xRet) == "L"
			lContinua  := xRet
		ElseIf ValType(xRet) == "A"
			If Len(xRet) >= 4
				aParcEsp   := AClone(xRet)
				lContinua  := .T.
			Else
			    lContinua  := .F.
			EndIf
		EndIf
	EndIf

	If lFTVD7009 .AND. lFtvdVer12
		xRet  := ExecBlock("FTVD7009",.F.,.F.,{aFTVD7009[1],aFTVD7009[2]})
		If ValType(xRet) == "L"
			lContinua  := xRet
		ElseIf ValType(xRet) == "A"
			If Len(xRet) >= 4
				aParcEsp   := AClone(xRet)
				lContinua  := .T.
			Else
			    lContinua  := .F.
			EndIf
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica se eh para ajustar as parcelas ou para retornar as informacoes³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lContinua
		If nLinha == 0
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Não permite inserir dois cartões quando não utiliza múltiplas transações TEF³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
          	If cPaisLoc == "BRA"
				lTransCart := lUsaTef
          	EndIf

			If lTransCart .AND. !SuperGetMV("MV_TEFMULT") .AND. AllTrim(cFormaRed) $ _FORMATEF .AND. Ascan(aPgtos, { |x| AllTrim(x[3]) $ _FORMATEF } ) > 0
				If !lAutoExB
					MsgStop(STR0105,STR0001) //"Para utilizar mais de um cartão como forma de pagamento você deve acionar o recurso de Múltiplas Transações TEF!"
				Else
					ConOut(STR0105) //"Para utilizar mais de um cartão como forma de pagamento você deve acionar o recurso de Múltiplas Transações TEF!"
				EndIf
				uRetorno := {}
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Dispara a geração das parcelas quando cadastradas pelo botão de condições³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			ElseIf nParc > 1 .AND. ((AllTrim(cFormaRed) $ _FORMATEF) .Or. (AllTrim(cFormaRed) == "FI" .And. lAtuPf )).AND. nValor <> 0
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Chamo a função de recalculo para que o sistema divida o valor das parcelas³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				Lj7CondPg(	3	, "CN"		, {"1 - Simples", dData, 0, 0, nParc, 30, .F., .F. }	,NIL	, ;
							NIL	, cFormaRed	, cFormaId												,nValor	, ;
							Nil, lTefPendCS)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Retorno a array zerada pois a função já preencheu o aPgtos³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				uRetorno := {}

			ElseIf nValor <> 0

				If (lLj7009 .AND. Len(aParcEsp) >= 4) .AND. !lFtvdVer12
					uRetorno := AClone(aParcEsp)
				ElseIf !lFtvdVer12
					uRetorno := { dData, nValor, aFormPgtos[aScan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})][1],cFormaId}
				EndIf

				If (lFTVD7009 .AND. Len(aParcEsp) >= 4) .AND. lFtvdVer12
					uRetorno := AClone(aParcEsp)
				ElseIf lFtvdVer12
					uRetorno := { dData, nValor, aFormPgtos[aScan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})][1],cFormaId}
				EndIf

				If cPaisLoc <> "BRA"
					aAdd(uRetorno, nMoedaParc)
					aAdd(uRetorno, dEmissao)
					aAdd(uRetorno, cChequeId)
					If IsMoney(uRetorno[3])
						cSimb := "MV_SIMB"+AllTrim(Str(nMoedaParc))
						uRetorno[3] := SuperGetMV(cSimb)
					EndIf
				EndIf

			Else
				uRetorno := {}
			EndIf

		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Soma os valores de aPgtos mais o que foi informado para fazer a validacao³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			uRetorno := Nil
			nVlrPago := 0
			nFixo    := 0

			If (lLj7009 .AND. Len(aParcEsp) >= 4) .AND. !lFtvdVer12
				dData    := aParcEsp[1]
			 	nValor   := aParcEsp[2]
			  	aFormas2[aScan(aFormas,cForma)]  := aParcEsp[3]
			  	lCheckPag := aParcEsp[4]

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³O 5º elemento do array LJ7009 (enviado e recebido do P.E. Lj7009) foi criado a posterior,             ³
				//³ por isto é conferido a sua existencia para proteger customizacoes anteriores                       ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			 	If Len(aParcEsp) >= 5
					cFormaID  := aParcEsp[5]
				EndIf
			EndIf

			If (lFTVD7009 .AND. Len(aParcEsp) >= 4) .AND. lFtvdVer12
				dData    := aParcEsp[1]
			 	nValor   := aParcEsp[2]
			  	aFormas2[aScan(aFormas,cForma)]  := aParcEsp[3]
			  	lCheckPag := aParcEsp[4]

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³O 5º elemento do array FTVD7009 (enviado e recebido do P.E. FTVD7009) foi criado a posterior,             ³
				//³ por isto é conferido a sua existencia para proteger customizacoes anteriores                       ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			 	If Len(aParcEsp) >= 5
					cFormaID  := aParcEsp[5]
				EndIf
			EndIf

			If cPaisLoc == "BRA"
				aEval(aPgtos, { |x, y| nVlrPago += x[2] })
			Else
				aEval( aPgtos, { |x, y| nVlrPago+=Round(xMoeda(x[2],x[_MOEDA],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)})
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Soma os valores das linhas e o novo valor digitado pelo usuario³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			For nConta := 1 to nLinha
				If nConta == nLinha
					nFixo      += Round(xMoeda(nValor,nMoedaParc,nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)
				ElseIf cPaisLoc == "BRA"
					nFixo      += aPgtos[nConta][2]
				Else
					nFixo      += Round(xMoeda(aPgtos[nConta][2],aPgtos[nConta][6],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)
				EndIf
			Next nConta

			If Len(aPgtos) > nLinha .AND. !lRecPar
				//Se houver reedição do Pagtos e não estiver sinalizado para recalcular parcelas, soma até a última
				//linha
				For nConta := ( nLinha + 1) to Len(aPgtos)
					If cPaisLoc == "BRA"
						nFixo      += aPgtos[nConta][2]
					Else
						nFixo      += Round(xMoeda(aPgtos[nConta][2],aPgtos[nConta][6],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)
					EndIf
				Next nConta
			EndIf
			nDiferenca := If(lRecPar, Abs( nVlrPago - nFixo ), 0)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Tratar diferencas de arredondamento quando as moedas das parcelas sao diferentes da moeda da venda³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cPaisLoc <> "BRA"
				nToler  := 1/(10**nDecimais)
				If nDiferenca <> 0 .AND. ABS(nDiferenca) <= nToler
					nFixo  := nVlrPago
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//|	A mensagem abaixo so sera apresentada caso o sistema nao	|
			//|	esteja utilizando o troco para qualquer numerario           |
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica se eh possivel informar esse valor³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If ( nFixo > nVlrPago .OR. nValor > nVlrPago ) .AND. !(aFormPgtos[aScan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})][1] $ cFormVale .OR.;
				IsMoney(aFormPgtos[aScan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})][1]) .Or. nFixo <= Lj7T_Total(2)) .AND.;
				(cPaisLoc == "BRA" .OR. !SuperGetMV("MV_LJTRLOC")) .AND. ( SL1->( FieldPos( "L1_TROCO1" ) ) <= 0 .OR. !GetNewPar( "MV_LJTROCO", .F. ) )
				If !lAutoExB
					MsgStop(STR0044) //"Foi ultrapassado o valor total da venda. Só será permitida a inclusão de numerário em Dinheiro"
				Else
					ConOut(STR0044) //"Foi ultrapassado o valor total da venda. Só será permitida a inclusão de numerário em Dinheiro"
				EndIf
				aPgtos  := AClone(aBckPgtos)

			Else
				If nValor <> 0
					aPgtos[nPosObj][1] := dData
					aPgtos[nPosObj][2] := nValor

					If aPgtos[nPosObj][3] <> aFormas2[aScan(aFormas,cForma)] // Forma Diferente
						aPgtos[nPosObj][4] := {}	// Caso tenha sido alterada a forma, deve limpar a ADM
					EndIf

					aPgtos[nPosObj][3] := aFormas2[aScan(aFormas,cForma)]
					aPgtos[nPosObj][8] := cFormaID

					If cPaisLoc <> "BRA"
						aPgtos[nPosObj][_MOEDA]  := nMoedaParc
						aPgtos[nPosObj][_EMISSAO]:= dEmissao
						If IsMoney(aPgtos[nPosObj,3])
							cSimb := "MV_SIMB"+AllTrim(Str(nMoedaParc))
							aPgtos[nPosObj,3] := SuperGetMV(cSimb)
						EndIf
					Else
						aPgtos[nPosObj][_MOEDA]	  := 1 //Se for Loc=="BRA" traz o padrão da moeda 1
					EndIf

					If Len(aPgtos) > 1  .AND. (lRecPar .OR. nDiferenca > 0)  //Incluida a validacao de alteração de parcela ou diferenca

						nRestDif := 0
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³ Recalcula o valor das parcelas restantes com o valor que sobrou.³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						For nX := ( nPosObj + 1 ) To Len(aPgtos)
							If cPaisLoc == "BRA"
								aPgtos[nX][02] := Round(( nDiferenca / ( Len(aPgtos) - nPosObj ) ), 2)
								nRestDif       += Round(( nDiferenca / ( Len(aPgtos) - nPosObj ) ), 2)
							Else
								nDifParc       := ( nDiferenca / ( Len(aPgtos) - nPosObj ) )
								aPgtos[nX][02] := xMoeda(nDifParc,nMoedaCor,aPgtos[nX][06],dDatabase)
								nRestDif       += Round(( nDiferenca / ( Len(aPgtos) - nPosObj ) ), nDecimais)
							EndIf
						Next nX
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³ Para que não dê diferenças o saldo que restou das divisões vão para a última parcela.³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If nRestDif <> nDiferenca

							nDiferenca := ( nDiferenca - nRestDif )

							If nPosObj <> Len(aPgtos)
								If nDiferenca > 0
									//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
									//³Esta faltando, soma a diferenca na ult. parcela ³
									//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
									If cPaisLoc == "BRA"
										aPgtos[Len(aPgtos)][02] += nDiferenca
									Else
										aPgtos[Len(aPgtos)][02] += xMoeda(nDiferenca,nMoedaCor,aPgtos[Len(aPgtos)][06],dDatabase)
									EndIf
								Else
									//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
									//³Esta sobrando, subtrai a diferenca da ult. parcela³
									//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
									If cPaisLoc == "BRA"
										aPgtos[Len(aPgtos)][02] -= -nDiferenca
									Else
										aPgtos[Len(aPgtos)][02] -= xMoeda(nDiferenca,nMoedaCor,aPgtos[Len(aPgtos)][06],dDatabase)
									EndIf
								EndIf
							EndIf

						EndIf
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Apaga as linhas que foram zeradas.³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						While ( nPos := aScan(aPgtos, { |x| x[02] == 0 }) ) > 0
							aDel(aPgtos, nPos)
							aSize(aPgtos, ( Len(aPgtos) - 1 ))
						End

						If cPaisLoc <> "BRA"
							nVlrTotal  := Lj7T_Total(2)
							nVlrPago   := 0
							aEval( aPgtos, { |x, y| nVlrPago+=Round(xMoeda(x[2],x[_MOEDA],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)})
							nDifArred  := nVlrTotal - nVlrPago
							If nDifArred <> 0 .AND. !SuperGetMV("MV_LJTRLOC")
								For nX := 1 to Len(aPgtos)
									If nX == nLinha
										Loop
									EndIf
									If aPgtos[nX][6] == nMoedaCor
										aPgtos[nX][2]  += nDifArred
										Exit
									EndIf
								Next nX
							EndIf
						EndIf
					EndIf
				Else
					aDel( aPgtos, nPosObj )
					aSize( aPgtos, (Len(aPgtos)-1) )
					If Len(aPgtos) == 0
						aPgtos := { { Ctod(Space(8)),;
										0,;
										Space(2),;
										{},;
						                 1,;
						                 If(cPaisLoc<>"BRA",1,NIL),If(cPaisLoc<>"BRA",Ctod(Space(8)),NIL),;
						                 If(lVisuSint,Space(TamSX3("L4_FORMAID")[1]),Space(01)),;
						                 Space(01),;
						                 0 ,;
						                 0 ,;
						                 0 } }
					EndIf
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se eh para ajustar as proximas parcelas com a forma de pgto ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lCheckPag
		   For nX := nPosObj + 1 To Len(aPgtos)
			  //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			  //³Só alterar as próximas parcelas iguais a originária devido ao controle de datas³
			  //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			  If !IsMoney(cCodForma) .AND. AllTrim(aPgtos[nX][3]) == AllTrim(cCodForma) .AND. AllTrim(aPgtos[nX][8]) == AllTrim(cFormaIdAnt)
			     aPgtos[nX][3] := aPgtos[nPosObj][3]
				 aPgtos[nX][8] := aPgtos[nPosObj][8]
				 // se limpou em cima ,deve replicar para os outros itens da parcelas
				 aPgtos[nX][4] := aPgtos[nPosObj][4]
				 aPgtos[nX][9] := aPgtos[nPosObj][9]
		      EndIf
		   Next nX
		EndIf
	Else
	    If nLinha == 0
		   uRetorno := {}
	    Else
		   uRetorno := Nil
	    EndIf
	EndIf
Else
   If nLinha == 0
      uRetorno := {}
   Else
      uRetorno := Nil
   EndIf

     //Zera array com a adm. financeira
   	If lNovRegDesc .AND. (cCodForma == "CC") .AND. Empty(aPgtos[1][1])
   		aAdmsFinRG := {}
	EndIf

EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Reordenacao do array conforme a selecao das formas de pagamento.      ³
//³Pagamentos em dinheiro, serao acumulados na primeira posição do array.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

nFor := Len(aPgtos)
nx   := 1

While nX <= nFor
	If ValType(aPgtos[nX][3]) == "C"
		If aPgtos[nX][3] == AllTrim(cSimbMoeda)
			If aPgtos[1][3] <>AllTrim(cSimbMoeda)
				nPos := nX+1
				AAdd(aPgtos, {})
				AIns(aPgtos, 1)
				aPgtos[1] := aPgtos[nPos]
				ADel(aPgtos, nX + 1)
				ASize(aPgtos,  Len(aPgtos)-1)
				cBkpFrmTrc := Lj7GetTrcForm()
			Else
				If nX <> 1
					aPgtos[1][2] += aPgtos[nX][2]
					ADel(aPgtos, nX)
					ASize(aPgtos,  Len(aPgtos)-1)
					nFor--
					cBkpFrmTrc := Lj7GetTrcForm()
				EndIf
			EndIf
		EndIf
	EndIf
	nX++
End
If !lAutoExB
	oPgtos:SetArray(aPgtos)
	oPgtos:Refresh()
EndIf
If Type("oPgtosAna") == "O" .And. !lAutoExB
	oPgtosAna:nAt:= Len(aPgtos)
	oPgtosAna:SetArray(aPgtos)
	oPgtosAna:Refresh()
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ajusta o Valor das Parcelas e o Valor do Troco³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cBkpFrmTrc := Lj7GetTrcForm()

LJ7AjustaTroco()

//Volta a forma de pagamento que tem troco
If !Empty(cBkpFrmTrc)
	Lj7SetTrcForm(cBkpFrmTrc)
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ajusta os valores de PIS/COFINS caso Haja                    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7PisCof(Nil,cCodForma)
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ATUALIZA A ARRAY SINTETIZADA³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lVisuSint .AND. lConfirma
	aPgtosSint:=Lj7MontPgt(aPgtos, NIL , NIL , lTefPendCS)
	If !lAutoExB
		oPgtosSint:SetArray( aPgtosSint )
		oPgtosSint:Refresh()
	EndIf
EndIf

Return uRetorno

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7ZeraPgtosºAutor³ Vendas Clientes    º Data ³  16/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Zera a array aPgtos, que contem as parcelas de pagamento    º±±
±±º          ³da venda                                                    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpL1 - Define se e para criar os objetos 				  º±±
±±º          ³ ExpA1 - Guarda a transacao TEF que foi aprovada            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ZeraPgtos(	lTefPendCS, aTefBKPCS, lIncFrete, aFormaEx,;
						nVlrAcrsFi)
Local nPosValItem   := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]
Local nPosValUnit   := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]
Local nTamLQ_CON    := TamSx3("LQ_CONDPG")[1]   // Tamanho do campo LQ_CONDPG
Local nTamE4_DES    := TamSX3("E4_DESCRI")[1]   // Tamanho do campo E4_DESCRI
Local nX            := 0	   // Variavel auxiliar para loop
Local nValFrete     := 0   // Valor do Frete
Local lCenVenda     := SuperGetMv("MV_LJCNVDA",,.F.) // validacao para cenario de vendas
Local lAutoExB      := IsBlind()    // Verifica se a rotina sera executada via execauto ou nao
Local nA            := 0            // Variavel auxilial para loop
Local nPosProd      := aScan(aHeader,{|x|AllTrim(x[2]) == "LR_PRODUTO" })	// Posicao no aHeader do LR_PRODUTO
Local lTemICMSol    := .F.          //Verifica se a venda tem ICMS Solidario
Local nIcmSolDif    := 0	           //Diferenca do valor do ICMS solidario COM ou SEM frete
Local nItem         := 1
Local aPgtoEx       := {}           //Excessão de forma de pagamento  
Local lAtuTotal     := .f.          //Total atualizado
Local lLjGetaTit    := ExistFunc("LjxRecGTit")
Local aTituloOri    := {}           //Array com os dados do array statico "aTitulo" com os valores originais da rotina de Recebimento de Titulo
Local nPosTitOri    := 0
Local nI            := 0
Local nTTotal       := 0            // Total da venda
Default lTefPendCS  := .F.          // Parametro putilizado para TEF
Default aTefBKPCS   := {}           // Parametro putilizado para TEF
Default lIncFrete   := .T.          // Incluir o valor do Frete no Valor Total
Default aFormaEx    := {}           //Formas de pagamentos excessões - que serão mantidas Exemplo: array := {"CC","CH"}
Default nVlrAcrsFi  := 0

//Limpo o Acrescimo financeiro (Tratamento devido a sujeira da MultNegociação)
If nVlrAcrsFi > 0
	nVlrAcrsFi := 0
Endif

//Zera o array de Descontos
Lj7Arred(1,3)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Nao zera os pagamentos se as chamadas desta funcao     ³
//³ocorrerem durante o processamento de bonus, visto que o³
//³bonus nao deve interferir no valor total da venda      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lCenVenda .AND. IsInCallStack("Lj7Bonus")
	Return Nil
EndIf

aAdmsFinRG := {}

nPerRDAnt := 0

aTx_Juros := {0,0,0,0}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³A variavel lAtuPgto esta  = T  para evitar que a condição de pagamento fique em branco³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lAtuPgto := .T.

//Realiza copia dos pagametos em excessão
If Len(aFormaEx) > 0
	For nX = 1 To Len(aFormaEx)
		nPosEx := aScan(aPgtos, {|x| x[3] == aFormaEx[nX] })
		If nPosEx > 0
			aAdd(aPgtoEx,aPgtos[nPosEx])
		EndIf
	Next nX	
EndIf	 

If Len(aPgtoEx) > 0
	aPgtos := aPgtoEx //Mantém os pagametos informados como excessão
Else
	aPgtos := { {Ctod(Space(8)),;
	            0,;
	            Space(2),;
	            {},;
	            NIL,;
	            If(cPaisLoc<>"BRA",nMoedaCor,1),;
	            If(cPaisLoc<>"BRA",Ctod(Space(8)),NIL),;
	            If(lVisuSint,Space(TamSX3("L4_FORMAID")[1]),Space(01)),;
	            Space(01),;
	            0} }
EndIf
            
If cPaisLoc <> "BRA"

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Zera as configuracoes de troco para a venda³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (Type("aMoedas") == "A") .AND. (Len(aMoedas) > 0)
		For nX := 1 to Len(aMoedas)
			aMoedas[nX][2] := 0
			aMoedas[nX][3] := 0
			aMoedas[nX][4] := 0
			aMoedas[nX][5] := 0
		Next nX
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Caso tenha juros ou desconto financeiro é necessario realizar o recalculo dos impostos variáveis...³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    If (aDadosJur[1] <> 0 .OR. aDadosJur[09] <> 0)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Zera o array aDadosJur³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		AEval(aDadosJur,{|x,y| aDadosJur[y]:=0 })
 		If !lAutoExB
			LJMsgRun(STR0089,,{|| aEval(aCols,{|x,y| MaFisAlt("IT_PRCUNI",x[nPosValUnit],y),; //"Fazendo o recalculo dos impostos..."
	       			 Lj7RecalImp(y,6,"IT_VALMERC",x[nPosValItem])}) })
  		Else
  			aEval(aCols,{|x,y| 	MaFisAlt("IT_PRCUNI",x[nPosValUnit],y),; //"Fazendo o recalculo dos impostos..."
       			 				Lj7RecalImp(y,6,"IT_VALMERC",x[nPosValItem])})
  		EndIf
	EndIf
EndIf

If Len(aAcrescimo) >= 2
	aAcrescimo[1] := 0
	aAcrescimo[2] := 0
EndIf

//se a venda possui ICMS Solidario, o valor de ICMS deve ser recalculado, pois o Frete altera a Base de Calculo
If MaFisFound("NF") .AND. MaFisRet(,"NF_VALSOL") > 0
	lTemICMSol := .T.
Else
	lTemICMSol := .F.
EndIf

// Incluir o valor de frete no total da venda
If lIncFrete
	nValFrete := Lj7CalcFrete( ,lTemICMSol, @nIcmSolDif, @lAtuTotal )
	lCalcFrete := .F. //Seta a variavel para .F. para que nao seja somado novamente o valor do frete no valor total dentro da funcao Lj7AjustaTroco
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³No produto localizado, o valor do desconto ja encontra-se³
//³aplicado ao Subtotal da venda                            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//Caso a limpeza dos pagamentos seja oriunda da função LJ7FRETE significa que estamos na tela de produtos, por esse motivo não devemos atualizar o total de mercadorias(LJ7T_Total).
//OBS: ao ir para a tela de pagamentos o valor é atualizado
If !lAtuTotal .AND. !IsinCallStack("LJ7FRETE")//ICMS SOLIDÁRIO JÁ AJUSTA O TOTAL
	If cPaisLoc == "BRA"
		LJ7T_Total( 2, Lj7T_Subtotal(2) - Lj7T_DescV(2) + nValFrete)
	Else
		LJ7T_Total( 2, Lj7T_Subtotal(2) + nValFrete )
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define a array aPgtos para o objeto oPgtos                          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lAutoExB
	oPgtos:SetArray( aPgtos )
	oPgtos:Refresh()
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Zera as variaveis da condicao de pagamento                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
M->LQ_CONDPG	:= Space(nTamLQ_CON)
M->LQ_JUROS 	:= 0
M->LQ_TIPOJUR 	:= 0
cDescCondPg		:= Space(nTamE4_DES)
cCondSE4 		:= Space(nTamLQ_CON)

If !lAutoExB
	If Type("M->LQ_CODMNEG") <> "U" 
		M->LQ_CODMNEG := Space(Len(M->LQ_CODMNEG))
	EndIf
	
	oCondPg:Refresh()
	oDescCondPg:Refresh()
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Zera o desconto no total apenas se foi informado depois da condicao ³
//³ de pagamento                                                        ³
//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
//³ Identifica em que momento foi dado o desconto no total              ³
//³ aDesconto[1] := 0	// Nao tem desconto                             ³
//³ aDesconto[1] := 1	// Antes da condicao de pagamento               ³
//³ aDesconto[1] := 2	// Depois da condicao de pagamento              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If aDesconto[1] == 2
    Lj7T_DescV( 2, 0 )
    Lj7T_DescP( 2, 0 )
    nTTotal   := Lj7T_Subtotal(2) - ( Lj7T_DescV(2) + nValFrete )   
    LJ7T_Total( 2, nTTotal )
    Lj7T_TotPar( 2, nTTotal )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Zerando o tipo de pagamento, deve ser zerado todos os desconto da   ³
	//³  regra de desconto, porem deve ser calculado novamente os descontos ³
	//³  somente por total sem tipo de pagto.                               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lNovRegDesc .AND. ExistFunc("LjSetDesFP")
		LjSetDesFP(0)	//reseta o array estatico aDescTotFP(LOJA3026.PRW)
		RGDesTol(.F., Lj7T_SubTotal(2), Nil, Nil, M->LQ_CLIENTE ,M->LQ_LOJA)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ajusta o Valor e o desconto dos titulos                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If Len (Atitulo) > 0 .And. lLjGetaTit
	//Resgata o array statico aTitulo original do fonte LOJXREC
	aTituloOri := LjxRecGTit()
	
	For nI := 1 To Len(aTitulo)
    	//Restaura os valores anteriores (tira o desconto financeiro)
    	If Len(aTituloOri) > 0 .And. ( nPosTitOri := aScan( aTituloOri, {|x| x[15]+x[02]+x[03]+x[04]+x[11] == aTitulo[nI][15]+aTitulo[nI][02]+aTitulo[nI][03]+aTitulo[nI][04]+aTitulo[nI][11] } ) ) > 0
        	aTitulo[nI][08] := aTituloOri[nPosTitOri][08]  // acrescimo condição de pagamento
        	aTitulo[nI][09] := aTituloOri[nPosTitOri][09]  // desconto  condicao de pagamento
        	aTitulo[nI][10] := aTituloOri[nPosTitOri][10]  // valor
    	EndIf
    Next nI	
	
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ajusta o Valor das Parcelas e o Valor do Troco                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7AjustaTroco()

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ajusta os valores de PIS/COFINS caso Haja                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7PisCof()

If lVisuSint
	aPgtosSint := Lj7MontPgt(aPgtos)
	If !lAutoExB
		oPgtosSint:SetArray( aPgtosSint )
		oPgtosSint:Refresh()
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se tiver alguma operacao TEF pendente, manda uma ³
//³nao-confirmacao.                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lTefPendCS
	oTEF:FinalTrn(0)
	lTefPendCS := .F.
	aTefBKPCS  := {}
EndIf

//------------------------------------------------------
//  Zera o controle de cálculo do vencimento das administradoras financeiras
aVldVencPc := {}

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7InfPgtosºAutor ³ Vendas Clientes    º Data ³  02/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se eh necessario pegar as informacoes de cheque    º±±
±±º          ³e / ou administradora financeira                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Void  Lj7InfPgtos(ExpN1, Exp2 )                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³ExpN1 - tipo da operacao                                    º±±
±±º          ³      1 - Salvar como orcamento                             º±±
±±º          ³      2 - Salvar como venda                                 º±±
±±º          ³      3 - Salvar como pedido                                º±±
±±º          ³Exp2  - Array Vale Compra                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7InfPgtos( nTipo		, aVales	, nMoedaAux	, lJob ,;
					  aAuxaPgtos, aTaxJuros	, aTefBKP   )
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Estrutura do array aDadosChq                                        ³
//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
//³ Linha [1] - Dados                                                   ³
//³ Linha [2] - Objetos                                                 ³
//³ Linha [3] - Define as informacoes obrigatorias                      ³
//³ Linha [4] - Titulo dos campos                                       ³
//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
//³ [n][1] - Valor da parcela                                           ³
//³ [n][2] - Data do vencimento                                         ³
//³ [n][3] - Numero da parcela                                          ³
//³ [n][4] - Banco                                                      ³
//³ [n][5] - Agencia                                                    ³
//³ [n][6] - Conta                                                      ³
//³ [n][7] - Numero do cheque                                           ³
//³ [n][8] - Compensacao                                                ³
//³ [n][9] - RG                                                         ³
//³ [n][10] - Telefone                                                  ³
//³ [n][11] - Utiliza nas proximas parcelas                             ³
//³ [n][12] - Cheques de terceiros                                      ³
//³ [n][13] - Simbolo da Moeda(Localizacoes)                            ³
//³ [n][14] - Emitente                                                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Estrutura do array aDadosAdm                                        ³
//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
//³ Linha [1] - Dados                                                   ³
//³ Linha [2] - Objetos                                                 ³
//³ Linha [3] - Define as informacoes obrigatorias                      ³
//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
//³ [n][1] - Valor da parcela                                           ³
//³ [n][2] - Data do vencimento                                         ³
//³ [n][3] - Numero da parcela                                          ³
//³ [n][4] - Numero do cartao                                           ³
//³ [n][5] - Administradora                                             ³
//³ [n][6] - Utiliza nas proximas parcelas                              ³
//³ [n][7] - 4 ult.dig.cartao magnetico ou ID Cartao - Nova visualização³
//³ [n][8] - Banco associado ao cartao utilizado                        ³
//³ [n][9] - Desconto                                                   ³
//³ [n][10] - Gera fin                                                  ³
//³ [n][11] - Banco                                                     ³
//³ [n][12] - Total Desconto                                            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lCheckParc:= .T.
Local cSimbMoeda:= ""
Local aAux		:= {}                                                  // Array temporario com as parcelas
Local aDadosChq	:= {}
Local nTamBc	:= TamSX3("A1_COD")[1]									// TAMANHO DO CAM BANCO
Local aDadosAdm	:= { { 0,dDatabase,1,Space(TamSx3("L4_NUMCART")[1]),Space(TamSx3("L4_ADMINIS")[1]),.T.,space(4),"", 0, .F., PadR( '' , nTamBc ),0, Space(TamSx3("AE_DESC")[1]) , Space(TamSx3("AE_TIPO")[1]) },;
						Array(8),;
						{ .F., .F., .F., .F., .T., .F.,.F.,.F. } }
Local nPos		:= 0
Local aAdminist	:= {}
Local aCMC7		:= {}								// Array contendo dados do CMC7
Local lBotaoOk 	:= .F.								// Variavel logica referente ao botão OK
Local lContinua	:= .T.								// Variavel que recebe validação
Local lCancela 	:= .F.								// Variavel que recebe validação do cancelamento sda tela de dados do cheque
Local nCont,nX 	:= 0								// Variavel contador
Local nY		:= 0								// Variavel contador
Local nZ		:= 0 								// Variavel para controle de laco
Local nVezes 	:= 0								// Variavel contador
Local cMens 	:= ""								// Variavel que recebe mensagens
Local cDescri   := "" 								// Variavel que recebe a descrição
Local cMV_PRXPARC := SuperGetMV("MV_PRXPARC")  		// Controla o conteudo DEFAULT da opcao "Utiliza nas proximas parcelas"
Local oDlgChq, oDlgAdm								// Objeto da tela de adm fim e dados do cheque
Local oBt1,oBt2										// Objeto do botão
Local lLJ7021	:= ExistBlock("LJ7021")     		// Variavel que recebe ponto de entrada
Local lDadosFin  									// Variavel para validar se deve ser exibida tela para dados da financiadora
Local lMV_LJRest   := GetNewPar("MV_LJREST",.F.) 	// Utiliza ambiente de Restaurante?
Local bActionBt1 									// Variavel utilizada no action do botao das administradoras qdo usa vale-compra
Local bActionBt2 									// Variavel utilizada no action do botao das administradoras qdo nao usa vale-compra
Local lAutoExB	:= IsBlind()						// Verifica se a rotina sera executada via execauto ou nao


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Variaveis utilizada no vale compra³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lUsafd      	:= SuperGetMV("MV_LJUSAFD",,.F.) 		// Utiliza Fidelizacao de cliente ??
Local oDlgNrVale
Local oGetDadMAV
Local cNroVale		:= ""
Local cCodVale		:= ""
Local nCntFor		:= 0
Local aHeaderMAV	:= {}
Local aColsMAV		:= {}
Local aCamposMAV	:= {}
Local lControlaVale	:= .F.												// Identifica se vai pedir o numero do vale compras na tela da administradora
Local cCodAdmin		:= "" 												// Codigo da administradora. Utilizado para buscar no SAE se a ADM controla ou nao os vales-compras
Local oGetDad															// Get Dados com numero dos Vale-Compras
Local lLJ7039       := (ExistBlock("LJ7039"))	            			// Ponto de entrada antes de apresentar a tela de parcelas
Local nTamEF_NUM    := TamSX3("EF_NUM")[1]                 				// Tamanho do campo EF_NUM
Local nTamAE_COD    := TamSx3("AE_COD")[1]                 				// Tamanho do campo AE_COD
Local nTamL4_NUM    := TamSX3("L4_NUMCART")[1]             				// Tamanho do campo L4_NUMCART
Local lMVTELAFIN	:= SuperGetMv("MV_TELAFIN",,.T.)					// Define se mostra a tela de administradora
Local nF 			:= 0												// Variavel contador
Local aBkpAdmFin	:= {}												// BackUp do aAdmFinanc
Local cFormVale		:= IIf(SuperGetMV("MV_LJVALEP",,.F.),"FI|BO|BOL|VP","FI|BO|BOL")	// Utiliza Vale Presente
Local nVlrDesc		:= 0												// Desconto

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Release 11.5 - Cartao Fidelidade³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lLjcFid 		:= SuperGetMv("MV_LJCFID",,.F.) .AND. CrdxInt()		//Indica se a recarga de cartao fidelidade esta ativa
Local aNumCFid		:= {}												//Array com dados do cartao fidelidade que será clonado no arrau aAux
Local cNumCFid		:= ""												//Numero do cartao fidelidade informado como forma de pagamento.
Local nFid			:=	0												//Contador
Local lPRecFid		:= .F.												//Indica se a venda contem produto do tipo recarga de cartao fidelidade
Local nPosProd		:= 0 												// Guarda posicao do campo LR_PRODUTO para procura no aColsDet

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Variavel que verifica se o sistema está configurado para trabalhar com Comunicacao direta no CMC7³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local lComCMC7Dir	:= IIF(ExistFunc("LJCOMCMC7D"),LjComCMC7D(),.F.)	//Caso a funcao LjComCMC7D() existe verifico ela, caso contrario retorno .F.
Local lFTVD7021		:= ExistBlock("FTVD7021")     						// Variavel que recebe ponto de entrada
Local lFTVD7039     := (ExistBlock("FTVD7039"))	        				// Ponto de entrada antes de apresentar a tela de parcelas
Local lMvJurCc		:= SuperGetMV("MV_LJJURCC",NIL,.F.) 				//Parametro de juros de cartao de credito
Local lInibirAdmF	:= SuperGetMv("MV_LJADMFI", NIL, .F. ) 				// Indica se deve INIBIR(.T.) a tela de administradora financeira e faz a leitura direto do pin pad
Local cMvFormaFi	:= AllTrim(SuperGetMV("MV_FORMAFI",,""))			// Indica as formas de pagto que deverão apresentar a TELA ADMINISTRADORA mesmo com o parâmetro MV_LJADMFI=.T.
Local lSLGUCTef		:= IIf(TEF_CLISITEF == LjGetStation("TIPTEF"),.T.,.F.)		// Variavel que ajuda na verificação qual tef a estação usa
Local lJaSelec		:= .F.												// Procura se a Adm ja nao tenha sido selecionada anteriormente.
Local cRetLJ7028 	:= ""
Local lSelAdmin 	:= .F.												//Permite exibir janela selecionar administradora Financeira
Local lTemValeP		:= .F.												//Se escolheu Vale Presente em uma das formas de pagamento
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()											//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local nLjPagto		:= SuperGetMV("MV_LJPAGTO",NIL,1)					// Define de onde vai pegar a descrição da forma de Pagamento | 1 - Tabela 24 da SX5 | 2 - SAE

Default aVales		:= {}
Default nMoedaAux	:= 1
Default nTipo  		:= 0
Default lJob 		:= .F.
Default aAuxaPgtos	:= {}
Default aTaxJuros	:= {}
Default aTefBKP		:= {}

If !lJob
	nPosProd	:= Ascan(aHeaderDet,{|x| AllTrim(Upper(x[2])) == "LR_PRODUTO"}) // Cartao Fidelidade
	aBkpAdmFin  := aClone(aAdmFinanc)

	If lLj7039 .AND. !lFtvdVer12
	   ExecBlock("LJ7039",.F.,.F.)
	EndIf

	If lFTVD7039 .AND. lFtvdVer12
	   ExecBlock("FTVD7039",.F.,.F.)
	EndIf

	nMoedaAux := nMoedaCor
Endif

cSimbMoeda	:= SuperGetMV("MV_SIMB"+Ltrim(Str(nMoedaAux)))
If !lFtvdVer12
	aDadosChq	:= { {	0								, dDatabase						, 1							, Space(TamSx3("EF_BANCO")[1])	, ;
						Space(TamSx3("EF_AGENCIA")[1])	, Space(TamSx3("EF_CONTA")[1])	, Space(TamSx3("EF_NUM")[1]),Space(TamSx3("EF_COMP")[1])	, ;
	                   	Space(TamSx3("L4_RG")[1])		, Space(TamSx3("L4_TELEFON")[1]),.F.,.F.,cSimbMoeda, Space(TamSx3("EF_EMITENT")[1])},;
	                   	Array(14), { .F., .F., .F., .T., .T., .T., .T., .F., .F., .F., .F., .F., .F., .F. },;
	                   	{ STR0049, STR0050, STR0051, STR0052, STR0053, STR0054, STR0055,; //"Valor do Titulo"###"Data do Vencimento"###"Parcela"###"Banco"###"Agência"###"Conta"###"Num.Cheque"
						STR0056, RetTitle("A1_RG"), STR0058, STR0046, STR0059, STR0078, STR0147 } } //"Compensação"###"RG"###"Telefone"###"Utiliza nas próximas parcelas"###"Cheque de Terceiro" //"Moeda"###"Emitente"
ElseIf lFtvdVer12
	aDadosChq	:= { {	0								, dDatabase						, 1							, Space(TamSx3("EF_BANCO")[1])	, ;
					Space(TamSx3("EF_AGENCIA")[1])	, Space(TamSx3("EF_CONTA")[1])	, Space(TamSx3("EF_NUM")[1]),Space(TamSx3("EF_COMP")[1])	, ;
                   	Space(TamSx3("L4_RG")[1])		, Space(TamSx3("L4_TELEFON")[1]),.F.,.F.,cSimbMoeda, Space(TamSx3("EF_EMITENT")[1]),Space(TamSx3("EF_HIST")[1])},;
                   	Array(15), { .F., .F., .F., .T., .T., .T., .T., .F., .F., .F., .F., .F., .F., .F.,.F. },;
                   	{ STR0049, STR0050, STR0051, STR0052, STR0053, STR0054, STR0055,; //"Valor do Titulo"###"Data do Vencimento"###"Parcela"###"Banco"###"Agência"###"Conta"###"Num.Cheque"
					STR0056, RetTitle("A1_RG"), STR0058, STR0046, STR0059, STR0078, STR0147,STR0195 } } //"Compensação"###"RG"###"Telefone"###"Utiliza nas próximas parcelas"###"Cheque de Terceiro" //"Moeda"###"Emitente"//"Historico"
EndIf

If lJob
	aPgtos 		:= aClone( aAuxaPgtos )
	lVisuSint	:= If(SL4->(FieldPos("L4_FORMAID"))>0,.T.,.F.)
	If lVisuSint
		aPgtosSint := Lj7MontPgt(aPgtos, nMoedaAux, lJob , Len(aTefBKP) > 0)
	Endif
Endif
aAux := aClone( aPgtos )
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Acrescenta uma coluna em aPgtos para receber os dados da forma de pgto ³
//³e uma coluna em aAux para controle                                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Len(aPgtos[Len(aPgtos)]) == 3
	aEval( aPgtos, {|x| aAdd(x,{}) } )
EndIf

aEval( aAux, { |x,y| x[5] := y } )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz o controle da interface com o ususrio para pegar os dados da Financiadora  |
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nX := 1
While nX <= Len(aAux) .AND. !lCancela .AND. !lLayAway
	If lMV_LJRest
		If FindFunction("LjRestFin")
	  		lDadosFin := LjRestFin( aAux , nX )
	  	EndIf
	Else
	  lDadosFin := Empty(aAux[nX][4])
	EndIf

	If !IsMoney(aAux[nX][3]) .AND. !Empty(aAux[nX][3]) .AND. lDadosFin

		nVezes := 0
		aEval( aAux, {|x| If(Trim(x[3])==Trim(aAux[nX][3]),nVezes++,Nil) } )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Faz o tratamento para Cheque                                           ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Trim(aAux[nX][3]) == Trim(MVCHEQUE)
			nCont := 0

		        nCont ++
				lBotaoOk := .F.
				lCheckParc      := (AllTrim(aAux[nX][3]) $ cMV_PRXPARC) .And. Len(aAdmsFinRG) == 0

				aDadosChq[1][1] := aPgtos[nX][2]
				aDadosChq[1][2] := aPgtos[nX][1]
				aDadosChq[1][3] := StrZero(nX,2,0)
				If cPaisLoc <> "BRA"
				   aDadosChq[1][13] := SuperGetMV("MV_SIMB"+LTrim(Str(aPgtos[nX][_MOEDA])))
				EndIf

				SA1->(DbSetOrder(1))
				If !lJob
					SA1->(DbSeek(xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA))
				Else
					SA1->(DbSeek(xFilial("SA1")+SL1->L1_CLIENTE+SL1->L1_LOJA))
				Endif

				aDadosChq[01,09] := SA1->A1_RG
				aDadosChq[01,10] := SA1->A1_TEL
				aDadosChq[01][11] := lCheckParc
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Verifica se usa o CMC7 e faz o tratamento                              ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				lContinua := .T.
				aCMC7 := {}
				While lContinua .AND. Empty(aCMC7) .AND. (lUsaCmc7 .OR. lComCMC7Dir)
					aCMC7 := LjLeCMC7( nX )
					If !Empty(aCMC7)
						aDadosChq[1][4] := aCMC7[1]	// Banco
						aDadosChq[1][7] := aCMC7[2]	// Num.Cheque
						aDadosChq[1][5] := aCMC7[3]	// Agencia
						aDadosChq[1][6] := aCMC7[4]	// Conta
						aDadosChq[1][8] := aCMC7[5]	// Compensacao
					EndIf

					If Empty(aCMC7)
						If Aviso(STR0015, STR0060,;	//"Atenção"###"Não foi possível ler os dados do cheque. Deseja tentar novamente ?"
						{STR0061,STR0062}) == 1    	//"Sim"###"Digitar"
							lContinua := .T.
						Else
							lContinua := .F.
						EndIf
					EndIf
				End

				lContinua := .T.
				If SuperGetMV("MV_INFCHEQ")
					If !lJob
						While lContinua .AND. !lCancela
							If ExistBlock("LJ7054") .AND. !lFtvdVer12
								aDadosChq[1] := AClone(Execblock("LJ7054",.F.,.F.,{aDadosChq[1]}))
								If ValType(aDadosChq[1]) <> "A" .OR. Len(aDadosChq[1]) == 0
									lCancela := .T.
								Else
									lBotaoOk := .T.
								EndIf

							ElseIf ExistBlock("FTVD7054") .AND. lFtvdVer12
								aDadosChq[1] := AClone(Execblock("FTVD7054",.F.,.F.,{aDadosChq[1]}))
								If ValType(aDadosChq[1]) <> "A" .OR. Len(aDadosChq[1]) == 0
									lCancela := .T.
								Else
									lBotaoOk := .T.
								EndIf

							ElseIf lFtvdVer12

							DEFINE MSDIALOG oDlgChq FROM 18, 13 TO 42, 66 TITLE STR0063 OF oDlgVA //"Dados do Cheque"

								@ .3,1 TO 2.9,25.2 OF oDlgChq
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Valor do título:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								@ 01.0, 02.0 SAY aDadosChq[4][1] SIZE 17,1 FONT aFontes[1] OF oDlgChq
								@ 01.0, 12.0 SAY aDadosChq[2][1] VAR aDadosChq[1][1] SIZE 10,1 PICTURE PesqPict("SL1","L1_VLRTOT") RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgChq
								If cPaisLoc <> "BRA"
								   @ 01.0, 22.0 SAY "("+aDadosChq[1][13]+")" SIZE 06,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgChq
								EndIf
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Data do Vencimento:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 02.0, 02.0 SAY aDadosChq[4][2] SIZE 17,1 FONT aFontes[1] OF oDlgChq
								@ 02.0, 10.0 SAY aDadosChq[2][2] VAR aDadosChq[1][2] SIZE 8,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgChq
								//ÚÄÄÄÄÄÄÄÄÄ¿
								//³ Parcela:³
								//ÀÄÄÄÄÄÄÄÄÄÙ
								@ 02.0, 15.0 SAY aDadosChq[4][3] SIZE 8,1 FONT aFontes[1] OF oDlgChq
								@ 02.0, 20.0 SAY aDadosChq[2][3] VAR aDadosChq[1][3] SIZE 5,1 RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgChq

								@ 3,1 TO 11.3,25.2 OF oDlgChq
								//ÚÄÄÄÄÄÄÄ¿
								//³ Banco:³
								//ÀÄÄÄÄÄÄÄÙ
								@ 4.0,02 Say aDadosChq[4][4] SIZE 10,1 OF oDlgChq
								@ 4.0,05 MSGET aDadosChq[2][4] VAR aDadosChq[1][4] Picture PesqPict("SEF","EF_BANCO",3) SIZE 15, 1 OF oDlgChq
								  aDadosChq[2][4]:cSx1Hlp:="EF_BANCO"
								//ÚÄÄÄÄÄÄÄÄÄ¿
								//³ Agência:³
								//ÀÄÄÄÄÄÄÄÄÄÙ

								@ 4.0,08 Say aDadosChq[4][5] SIZE 10,1 OF oDlgChq
								@ 4.0,11 MSGET aDadosChq[2][5] VAR aDadosChq[1][5] Picture PesqPict("SEF","EF_AGENCIA",5) SIZE 18, 1 OF oDlgChq
								  aDadosChq[2][5]:cSx1Hlp:="EF_AGENCIA"
								//ÚÄÄÄÄÄÄÄ¿
								//³ Conta:³
								//ÀÄÄÄÄÄÄÄÙ
								@ 4.0,16 Say aDadosChq[4][6] SIZE 5,1
								@ 4.0,18 MSGET aDadosChq[2][6] VAR aDadosChq[1][6] Picture PesqPict("SEF","EF_CONTA",10) SIZE 36, 1 OF oDlgChq
								  aDadosChq[2][6]:cSx1Hlp:="EF_CONTA"
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Num Cheque:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 5.0,02 Say aDadosChq[4][7] SIZE 15,1 OF oDlgChq
								@ 5.0,07 MSGET aDadosChq[2][7] VAR aDadosChq[1][7] Picture PesqPict("SEF","EF_NUM",15) SIZE 51, 1 OF oDlgChq
								  aDadosChq[2][7]:cSx1Hlp:="EF_NUM"
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Compensação:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 5.0,14 Say aDadosChq[4][8] SIZE 10,1 OF oDlgChq
								@ 5.0,19 MSGET aDadosChq[2][8] VAR aDadosChq[1][8] Picture PesqPict("SL4","L4_COMP",3) SIZE 10,1 OF oDlgChq
								  aDadosChq[2][8]:cSx1Hlp:="L4_COMP"
								//ÚÄÄÄÄ¿
								//³ RG:³
								//ÀÄÄÄÄÙ

								@ 6.0,02 Say aDadosChq[4][9] SIZE 10,1 OF oDlgChq
								@ 6.0,04 MSGET aDadosChq[2][9] VAR aDadosChq[1][9] Picture PesqPict("SEF","EF_RG",15) SIZE 51, 1 OF oDlgChq
								  aDadosChq[2][9]:cSx1Hlp:="EF_RG"
								//ÚÄÄÄÄÄÄÄÄÄÄ¿
								//³ Telefone:³
								//ÀÄÄÄÄÄÄÄÄÄÄÙ

								@ 6.0,11 Say aDadosChq[4][10] SIZE 10,1 OF oDlgChq
								@ 6.0,14 MSGET aDadosChq[2][10] VAR aDadosChq[1][10] Picture PesqPict("SEF","EF_TEL",15) SIZE 51,1 OF oDlgChq
								 aDadosChq[2][10]:cSx1Hlp:="EF_TEL"

								//ÚÄÄÄÄÄÄÄÄÄÄ¿
								//³ Historico³
								//ÀÄÄÄÄÄÄÄÄÄÄÙ
								If SEF->(FieldPos("EF_HIST")) > 0
									@ 7,2 Say aDadosChq[4][15] SIZE 10,1 OF oDlgChq
									@ 7,5 MSGET aDadosChq[2][15] VAR aDadosChq[1][15] Picture PesqPict("SEF","EF_HIST",15) SIZE 130,1 OF oDlgChq
									aDadosChq[2][15]:cSx1Hlp:="EF_HIST"
								EndIf

								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Cheque de Terceiro³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 107,17 CHECKBOX aDadosChq[2][12] VAR aDadosChq[1][12] PROMPT aDadosChq[4][12] ON CHANGE Lj7EmitTer(@aDadosChq, @oDlgChq) SIZE 70,7 OF oDlgChq
								//ÚÄÄÄÄÄÄÄÄ¿
								//³Emitente³
								//ÀÄÄÄÄÄÄÄÄÙ
								@ 9,2 Say aDadosChq[4][14] SIZE 10,1 OF oDlgChq
								@ 9,5 MSGET aDadosChq[2][14] VAR aDadosChq[1][14] Picture PesqPict("SEF","EF_EMITENT",15) SIZE 130,1 OF oDlgChq
								  aDadosChq[2][15]:cSx1Hlp:="EF_EMITENT"


								aDadosChq[2][14]:Disable()
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Utiliza nas próximas parcelas³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								@ 140,17 CHECKBOX aDadosChq[2][11] VAR aDadosChq[1][11] PROMPT aDadosChq[4][11] SIZE 90,7 WHEN (nVezes>1.AND.nVezes>nCont) OF oDlgChq


								DEFINE SBUTTON FROM 162,137 TYPE 1 ACTION (lBotaoOk := .T.,oDlgChq:End()) ENABLE OF oDlgChq

								DEFINE SBUTTON FROM 162,171.1 TYPE 2 ACTION (lCancela:=.T.,oDlgChq:End()) ENABLE OF oDlgChq


								ACTIVATE MSDIALOG oDlgChq CENTERED

							Else

								DEFINE MSDIALOG oDlgChq FROM 12, 13 TO 32, 66 TITLE STR0063 OF oDlgVA //"Dados do Cheque"

								@ .3,1 TO 2.9,25.2 OF oDlgChq
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Valor do título:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								@ 01.0, 02.0 SAY aDadosChq[4][1] SIZE 17,1 FONT aFontes[1] OF oDlgChq
								@ 01.0, 12.0 SAY aDadosChq[2][1] VAR aDadosChq[1][1] SIZE 10,1 PICTURE PesqPict("SL1","L1_VLRTOT") RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgChq
								If cPaisLoc <> "BRA"
								   @ 01.0, 22.0 SAY "("+aDadosChq[1][13]+")" SIZE 06,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgChq
								EndIf
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Data do Vencimento:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 02.0, 02.0 SAY aDadosChq[4][2] SIZE 17,1 FONT aFontes[1] OF oDlgChq
								@ 02.0, 10.0 SAY aDadosChq[2][2] VAR aDadosChq[1][2] SIZE 8,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgChq
								//ÚÄÄÄÄÄÄÄÄÄ¿
								//³ Parcela:³
								//ÀÄÄÄÄÄÄÄÄÄÙ
								@ 02.0, 15.0 SAY aDadosChq[4][3] SIZE 8,1 FONT aFontes[1] OF oDlgChq
								@ 02.0, 20.0 SAY aDadosChq[2][3] VAR aDadosChq[1][3] SIZE 5,1 RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgChq

								@ 3,1 TO 9.3,25.2 OF oDlgChq
								//ÚÄÄÄÄÄÄÄ¿
								//³ Banco:³
								//ÀÄÄÄÄÄÄÄÙ
								@ 4.0,02 Say aDadosChq[4][4] SIZE 10,1 OF oDlgChq
								@ 4.0,05 MSGET aDadosChq[2][4] VAR aDadosChq[1][4] Picture PesqPict("SEF","EF_BANCO",3) SIZE 15, 1 OF oDlgChq
								  aDadosChq[2][4]:cSx1Hlp:="EF_BANCO"
								//ÚÄÄÄÄÄÄÄÄÄ¿
								//³ Agência:³
								//ÀÄÄÄÄÄÄÄÄÄÙ

								@ 4.0,08 Say aDadosChq[4][5] SIZE 10,1 OF oDlgChq
								@ 4.0,11 MSGET aDadosChq[2][5] VAR aDadosChq[1][5] Picture PesqPict("SEF","EF_AGENCIA",5) SIZE 18, 1 OF oDlgChq
								  aDadosChq[2][5]:cSx1Hlp:="EF_AGENCIA"
								//ÚÄÄÄÄÄÄÄ¿
								//³ Conta:³
								//ÀÄÄÄÄÄÄÄÙ
								@ 4.0,16 Say aDadosChq[4][6] SIZE 5,1
								@ 4.0,18 MSGET aDadosChq[2][6] VAR aDadosChq[1][6] Picture PesqPict("SEF","EF_CONTA",10) SIZE 36, 1 OF oDlgChq
								  aDadosChq[2][6]:cSx1Hlp:="EF_CONTA"
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Num Cheque:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 5.0,02 Say aDadosChq[4][7] SIZE 15,1 OF oDlgChq
								@ 5.0,07 MSGET aDadosChq[2][7] VAR aDadosChq[1][7] Picture PesqPict("SEF","EF_NUM",15) SIZE 51, 1 OF oDlgChq
								  aDadosChq[2][7]:cSx1Hlp:="EF_NUM"
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Compensação:³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 5.0,14 Say aDadosChq[4][8] SIZE 10,1 OF oDlgChq
								@ 5.0,19 MSGET aDadosChq[2][8] VAR aDadosChq[1][8] Picture PesqPict("SL4","L4_COMP",3) SIZE 10,1 OF oDlgChq
								  aDadosChq[2][8]:cSx1Hlp:="L4_COMP"
								//ÚÄÄÄÄ¿
								//³ RG:³
								//ÀÄÄÄÄÙ

								@ 6.0,02 Say aDadosChq[4][9] SIZE 10,1 OF oDlgChq
								@ 6.0,04 MSGET aDadosChq[2][9] VAR aDadosChq[1][9] Picture PesqPict("SEF","EF_RG",15) SIZE 51, 1 OF oDlgChq
								  aDadosChq[2][9]:cSx1Hlp:="EF_RG"
								//ÚÄÄÄÄÄÄÄÄÄÄ¿
								//³ Telefone:³
								//ÀÄÄÄÄÄÄÄÄÄÄÙ

								@ 6.0,11 Say aDadosChq[4][10] SIZE 10,1 OF oDlgChq
								@ 6.0,14 MSGET aDadosChq[2][10] VAR aDadosChq[1][10] Picture PesqPict("SEF","EF_TEL",15) SIZE 51,1 OF oDlgChq
								  aDadosChq[2][10]:cSx1Hlp:="EF_TEL"
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Cheque de Terceiro³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

								@ 95,17 CHECKBOX aDadosChq[2][12] VAR aDadosChq[1][12] PROMPT aDadosChq[4][12] ON CHANGE Lj7EmitTer(@aDadosChq, @oDlgChq) SIZE 70,7 OF oDlgChq
								//ÚÄÄÄÄÄÄÄÄ¿
								//³Emitente³
								//ÀÄÄÄÄÄÄÄÄÙ
								@ 8,2 Say aDadosChq[4][14] SIZE 10,1 OF oDlgChq
								@ 8,5 MSGET aDadosChq[2][14] VAR aDadosChq[1][14] Picture PesqPict("SEF","EF_EMITENT",15) SIZE 130,1 OF oDlgChq
								  aDadosChq[2][14]:cSx1Hlp:="EF_EMITENT"

								aDadosChq[2][14]:Disable()
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³ Utiliza nas próximas parcelas³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								@ 120,17 CHECKBOX aDadosChq[2][11] VAR aDadosChq[1][11] PROMPT aDadosChq[4][11] SIZE 90,7 WHEN (nVezes>1.AND.nVezes>nCont) OF oDlgChq


								DEFINE SBUTTON FROM 132,137 TYPE 1 ACTION (lBotaoOk := .T.,oDlgChq:End()) ENABLE OF oDlgChq

								DEFINE SBUTTON FROM 132,171.1 TYPE 2 ACTION (lCancela:=.T.,oDlgChq:End()) ENABLE OF oDlgChq

								ACTIVATE MSDIALOG oDlgChq CENTERED

							EndIf

							If lCancela
								lContinua := .F.
							Else
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³Verifica se existem informacoes obrigatorias que nao foram informadas  ³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								cMens := ""
								For nY := 1 to Len(aDadosChq[1])
									If aDadosChq[3][nY] .AND. Empty(aDadosChq[1][nY])
										cMens := cMens + aDadosChq[4][nY] + ", "
									EndIf
								Next nY
								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³Caso tenha sido selecionado como cheque de terceiro porem nao foi informado o emetente³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								If aDadosChq[1][12] .AND. Empty(aDadosChq[1][14])
									cMens := cMens + aDadosChq[4][14] + ", "
								EndIf

								If !Empty(cMens)
									cMens := Substr(cMens,1,Len(cMens)-2)
									If !lAutoExB
										MsgStop(STR0064 + CRLF + cMens) //"Existem informações obrigatórias a serem informadas. Verifique os campos: "
									Else
										ConOut(STR0064 + CRLF + cMens) //"Existem informações obrigatórias a serem informadas. Verifique os campos: "
									EndIf
									lContinua := .T.
								Else
									//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
									//³Verifica se ainda tem parcelas a informar                              ³
									//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
									lContinua := .F.
								EndIf
							EndIf

						End
					EndIf
				Else
					lBotaoOk := .T.
				 	aDadosChq[1][5] := '.'
				 	aDadosChq[1][6] := '.'
				 	aDadosChq[1][7] := '.'
				 	aDadosChq[1][13] := 'R$'
				EndIf

				If lBotaoOk
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Utiliza nas próximas parcelas³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If aDadosChq[1][11]
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³ Alimenta a linha da parcela atual³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						aAux[nX][4] := aClone(aDadosChq[1])
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³ Alimenta as outras parcelas ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						For nCont := nX + 1  to Len(aAux)
							If AllTrim(aAux[nCont][3]) == AllTrim(aAux[nX][3])
								aDadosChq[1][7] := Soma1( Alltrim(aDadosChq[1][7] ) )
								aAux[nCont][4] := aClone(aDadosChq[1])

                                // Quando o usuario deseja replicar as informacoes do cheque,
                                // definir a data e o valor do cheque subsequente
								aAux[nCont][4][1] := aPgtos[nCont][2] // Valor do Cheque
								aAux[nCont][4][2] := aPgtos[nCont][1] // Data do Cheque
							EndIf
						Next nCont
						nX ++
					Else
						aAux[nX][4] := aClone(aDadosChq[1])
						aDadosChq[1][7] := Soma1( Alltrim(aDadosChq[1][7] ) )
						nX ++
					EndIf
				EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Cartao fidelidade - Release 11.5³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
        ElseIf lLjcFid .AND. Trim(aAux[nX][3]) == "FID" .AND. !lJob
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³O cartao de fidelidade nao podera ser utilizado como forma ³
			//³de pagamento para venda que tiver produto do tipo          ³
			//³recarga de cartao fidelidade (Ver parametro MV_LJPFID).    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			For nFid:=1 To Len(aColsDet)
				If LaFunhProd(aCols[nFid][nPosProd]) .AND. !(aCols[nFid][Len(aCols[nFid])])
					lPRecFid := .T.
				EndIf
			Next nFid

        	If lPRecFid

        		If !lAutoExB
	        		MsgStop (STR0177 + Trim(aAux[nX][3]) + STR0178)//"A forma de pagamento "#" não é valida para recarga de cartao fidelidade."
        		Else
        			Conout(STR0177 + Trim(aAux[nX][3]) + STR0178)//"A forma de pagamento "#" não é valida para recarga de cartao fidelidade."
        		EndIf
        		lCancela:= .T.
        	Else
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Cartao Fidelidade                                              ³
				//³Realiza Verificação do Cliente selecionado.                    ³
				//³Caso o Cliente tenha Cartao Fidelidade atrelado ao seu cadastro³
				//³exibe automaticamente o codigo na tela.                        ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				Ca280Exec("CA280CONCL" , Nil, 		Nil,Nil,;
									Nil, Nil, M->LQ_LOJA,Nil,;
 									Nil, M->LQ_CLIENTE)
				If Len(CA280GetAr()) > 0
					//Ler o Array com informacoes do Cartao Atrelado ao Cliente.
					cNumCFid := CA280GetAr()[1][1]
				EndIf
   				lCancela:= !(LaFunhPgto (oDlgVA,@cNumCFid,aPgtos))
   				Aadd(aNumCFid,cNumCFid)
   			Endif

   			lBotaoOk  := !lCancela

			If lCancela
				lContinua := .F.
			Else
				aAux[nX][4] := aClone(aNumCFid)
				aPgtosSint[nX][6] := aClone(aNumCFid)
				lContinua := .T.
			EndIf
			nX ++
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Só captura os dados pelo aPgtos detalhado quando o cliente não utiliza o novo conceito de TEF³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	    ElseIf !lVisuSint

	    	aAdminist := {}
			If lMv_LjRest
				If FindFunction("LjRestAdmFin")
					LjRestAdmFin( aAux , nX , @aBkpAdmFin , @aAdminist )
				EndIf
			Else
		    	aEval( aBkpAdmFin, {|x| IF( AllTrim(x[1])==AllTrim(aAux[NX][3]),aAdd(aAdminist, x[3] + " - " + Capital(x[2])),Nil) } )
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Identifica se alguma das administradoras controla vale compras        ³
			//³ (AE_VCOMPRA = SIM). Se afirmativo, habilita a tela para a digitacao   ³
			//³ dos vales-compras, caso negativo, mantem a tela so' com a ADM.        ³
			//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
			//³ IMPORTANTE: So faz este controle caso o parametro MV_LJUSAFD esteja   ³
			//³ ativo e se existir o campo AE_VCOMPRA                                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lUsafd .AND. SAE->( FieldPos( "AE_VCOMPRA" ) ) > 0
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Define lControlaVale como falso por DEFAULT³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				lControlaVale := .F.
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Inicializa o contador do looping³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nZ := 1
				While nZ <= Len( aAdminist ) .AND. !lControlaVale
					cCodAdmin := PadR( Substr(aAdminist[nZ],1,3), nTamAE_COD )
					If Posicione( "SAE", 1, xFilial("SAE") + cCodAdmin, "SAE->AE_VCOMPRA" ) == "1"
						lControlaVale := .T.
					EndIf
					nZ ++
				End
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Faz o tratamento para as Financiadores                                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nCont := 1

			If Empty(aAux[nX][4]) .OR. (If (lMVRest,Empty(aAux[nX][4][4]),.T.)) //Se o numero do cartao estiver em branco

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³A tela de solicitaçaõ de ADM não poderá ser exibida nos seg. casos:    ³
			//³1. TEF Discado, pois utilizamos esta inf. para chamar o software da ADM³
			//³2. Múltiplas Transações, pois utilizamos a informação dos dígitos      ³
			//³3. lUsaTEF estiver falso, ele solicita o número para gravação          ³
			//³4. Se o parâmetro LJSLFIN estiver como verdadeiro                      ³
			//³5. Se o parâmetro LJADMFI estiver como verdadeiro                      ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			    lCheckParc       := (AllTrim(aAux[nX][3]) $ cMV_PRXPARC) .And. Len(aAdmsFinRG) == 0
				If ( !GetNewPar("MV_LJSLFIN", .T.) .AND. !SuperGetMV("MV_TEFMULT") .AND. cTipTef <> TEF_DISCADO ) .Or. lInibirAdmF

					aDadosAdm[1][1] := aAux[nX][2]
					aDadosAdm[1][2] := aAux[nX][1]
					aDadosAdm[1][3] := StrZero(nX,2,0)
					aDadosAdm[1][5] := ""
					aDadosAdm[1][6] := lCheckParc
					aAux[nX][4]     := aClone(aDadosAdm[1])
					nx++

				Else

					lBotaoOk := .F.
					aDadosAdm[1][1] := aAux[nX][2]
					aDadosAdm[1][2] := aAux[nX][1]
					aDadosAdm[1][3] := StrZero(nX,2,0)
					If lMv_LjRest
						If FindFunction("LjRestAtuAdm")
							LjRestAtuAdm( @aDadosAdm , nTamL4_NUM , aAux , nX   )
						EndIf
					EndIf

					aDadosAdm[1][6] := lCheckParc

					DEFINE MSDIALOG oDlgAdm FROM 12, 20 TO If( lControlaVale, 33, 27 ), 60 TITLE STR0065 OF oDlgVA 	//"Financiadora"

					@ 00.3 , 01 TO 7,18.9 OF oDlgAdm
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Valor do t¡tulo:³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					@ 01.0, 02.0 SAY STR0066 SIZE 10,1 FONT aFontes[1] OF oDlgAdm  //"Valor do título:"
					@ 01.0, 11.0 SAY aDadosAdm[2][1] VAR aDadosAdm[1][1] SIZE 7,1 PICTURE PesqPict("SL1","L1_VLRTOT") RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Data do Vencimento:³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

					@ 02.0, 02.0 SAY STR0067 SIZE 10,1 FONT aFontes[1] OF oDlgAdm //"Data do Vencimento:"
					@ 02.0, 10.0 SAY aDadosAdm[2][2] VAR aDadosAdm[1][2] SIZE 8,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
					//ÚÄÄÄÄÄÄÄÄÄ¿
					//³ Parcela:³
					//ÀÄÄÄÄÄÄÄÄÄÙ
					@ 02.0, 14.0 SAY STR0068 SIZE 5,1 FONT aFontes[1] OF oDlgAdm //"Parcela:"
					@ 02.0, 17.2 SAY aDadosAdm[2][3] VAR aDadosAdm[1][3] SIZE 1,1 RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm

					If ! lUsaTef
						//ÚÄÄÄÄÄÄÄ¿
						//³Número:³
						//ÀÄÄÄÄÄÄÄÙ
						@ 03.0, 02.0 SAY STR0069 OF oDlgAdm //"Número:"
						@ 37.0, 60.5 MSGET aDadosAdm[2][4] VAR aDadosAdm[1][4] RIGHT SIZE 62,10 PIXEL OF oDlgAdm
					      aDadosAdm[2][4]:cSx1Hlp:="L4_ADMINIS"
					EndIf
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Administradora:³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					@ 04.0, 02.0 SAY STR0070 OF oDlgAdm //"Administradora:"
					@ 04.0, 07.5 MSCOMBOBOX aDadosAdm[2][5] VAR aDadosAdm[1][5] ITEMS aAdminist SIZE 80,40 OF oDlgAdm
					aDadosAdm[2][5]:cSx1Hlp:="L4_ADMINIS"
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Controle do bChange da administradora financeira. Valida se existe controle de   ³
					//³ vale-compras para habilitar ou desabilitar os controles ou o action do botao Ok  ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					aDadosAdm[2][5]:bChange := { || If( LJ7_VldAdm( Substr( aDadosAdm[1][5], 1, nTamAE_COD ) ),;
					      								( oBt1:bAction:=bActionBt1, If(oGetDad <> NIL,(oGetDad:oBrowse:lVisibleControl := .T.,oGetDad:Refresh()),.F.) ),;
					      								( oBt1:bAction:=bActionBt2, If(oGetDad <> NIL,(oGetDad:oBrowse:lVisibleControl := .F.,oGetDad:Refresh()),.F.) )) }


					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Utiliza nas próximas parcelas³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

					@ 67.0, 15.0 CHECKBOX aDadosAdm[2][6] VAR aDadosAdm[1][6] PROMPT STR0046 SIZE 90,7 PIXEL ; //"Utiliza nas próximas parcelas"
					                                       WHEN (nVezes>1) ON CHANGE LJ701BPAR(aDadosAdm,@oBt1) OF oDlgAdm
					If lUsaTef .AND. SuperGetMV("MV_TEFMULT")
						@ 82, 15 SAY STR0071 SIZE 100, 10 OF oDlgAdm PIXEL  //"Informe os 4 últimos dígitos do cartão:"
						@ 82, 115 MSGET aDadosAdm[2][7] VAR aDadosAdm[1][7] RIGHT SIZE 10,08 PIXEL WHEN !aDadosAdm[1][6] OF oDlgAdm
						aDadosAdm[2][7]:cSx1Hlp:="LJ701FCAR"
					EndIf

	        		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Vale Compra - Se o cliente utiliza campanha de fidelizacao e a                   ³
					//³forma de pagamento for VA, o Sistem assume que o pagamento                        ³
					//³e vale compra e solicita o numero do vale compra                                  ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lControlaVale
						aHeaderMAV := {}
						aColsMAV   := {}

						Aadd(aHeaderMAV,{RTrim(RetTitle("MAV_CODIGO")),"MAV_CODIGO","@!",;   //"Codigo"
										15,0,"Lj7PesqVale()",Nil,"C","",,,,,".F.",,,,})

						Aadd(aHeaderMAV,{RTrim(RetTitle("MAV_VALOR")),"MAV_VALOR","@E 9,999,999.99",;   //"VALOR"
										15,0,"",Nil,"N","","V",,,,".F.",,,,})

						nUsado := Len(aHeaderMAV)
						aColsMAV := Array( 1 , (nUsado+1) )
						aColsMAV[1,nUsado+1] := .F.
						For nCntFor := 1 To nUsado
							aColsMAV[1,nCntFor] := CriaVar(aHeaderMAV[nCntFor,2],.T.)
						Next nCntFor

						oGetDad := MsNewGetDados():New(87,08,140,150,;
													GD_INSERT + GD_DELETE + GD_UPDATE,;
													"AllwaysTrue",;
													"AllwaysTrue"	,;
													Nil,;
													{"MAV_CODIGO"}  ,;
													NIL				,;
													999				,;
													NIL				,;
													NIL				,;
													NIL				,;
													oDlgAdm			,;
													aHeaderMAV		,;
													aColsMAV )

						oGetDad:oBrowse:lVisibleControl:= LJ7_VldAdm( Substr( aDadosAdm[1][5], 1, nTamAE_COD ) )
						oGetDad:Refresh()


					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Define o bloco de codigo da acao do botao OK quando houver controle  ³
					//³ de vale-compras                                                      ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					bActionBt1 := { || (   lBotaoOk := Lj7CtrVale(oGetDad:aCols),;
											If(lBotaoOk, aVales:=oGetDad:aCols, Nil),;
											If(lBotaoOk, oDlgAdm:End(),Nil) ) }

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Define o bloco de codigo da acao do botao OK quando nao houver       ³
					//³ controle de vale-compras                                             ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					bActionBt2 := { || ( lBotaoOk := .T., oDlgAdm:End() ) }

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Define o botao Ok dependendo do controle de vale-compras             ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lControlaVale
						DEFINE SBUTTON oBt1 FROM 145, 088 TYPE 1 ENABLE OF oDlgAdm
						oBt1:bAction := bActionBt1
					Else
						DEFINE SBUTTON oBt1 FROM 100, 088 TYPE 1 ENABLE OF oDlgAdm
						oBt1:bAction := bActionBt2
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Define o botao de cancelamento                                       ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					DEFINE SBUTTON oBt2 FROM If( lControlaVale, 145, 100 ),121.1 TYPE 2 ACTION (lCancela := .T.,oDlgAdm:End()) ENABLE OF oDlgAdm

					ACTIVATE MSDIALOG oDlgAdm CENTERED

					If !lCancela .AND. lBotaoOk
						If aDadosAdm[1][6]
							For nCont := nX to Len(aAux)
								If AllTrim(aAux[nCont][3]) == AllTrim(aAux[nX][3])
									aAux[nCont][4] := aClone(aDadosAdm[1])
								EndIf
							Next nCont
							aDadosAdm[2][4] := Space(nTamL4_NUM)
						Else
							aAux[nX][4] := aClone(aDadosAdm[1])
						EndIf
						nX ++
					EndIf

				EndIf
			Else
				nX ++
			EndIf
		Else
			nX ++
		EndIf
	Else
		nX ++
	EndIf
End

If lJob
	DbSelectArea("SAE")
	DbSetOrder(1)	// AE_FILIAL + AE_COD
	DbSeek( xFilial("SAE") )

	While SAE->AE_FILIAL == xFilial("SAE") .AND. !Eof()
		If !(AllTrim(SAE->AE_TIPO) $ MVCHEQUE .OR. IsMoney(SAE->AE_TIPO))
		    If SX5->(DbSeek(xFilial("SX5")+"24"+AllTrim(SAE->AE_TIPO)))
		    	aAdd( aBkpAdmFin, { AllTrim(SAE->AE_TIPO), SAE->AE_DESC, SAE->AE_COD } )
			EndIf
		EndIf
		SAE->(DbSkip())
	End
Endif
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz o tratamento para a digitação da FINANCIADORA com os dados sintetizados ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If lVisuSint
	nX := 1
	While nX <= Len(aPgtosSint) .AND. !lCancela .AND. !lLayAway

       	//Verificar se teve pagamento em Vale-Presente
      	lTemValeP := (aPgtosSint[nX][1] == "VP")

		If !Empty(aPgtosSint[nX][1]) .AND. !IsMoney(AllTrim(aPgtosSint[nX][1])) .AND. Trim(aPgtosSint[nX][1]) <> Trim(MVCHEQUE) .AND. Empty(aPgtosSint[nX][6]) .AND. Trim(aPgtosSint[nX][1]) <> "FID"

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Alimenta o array aAdminist que vai ser usado pelo combo box das       ³
			//³ administradoras                                                       ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			aAdminist := {}
			aEval( aBkpAdmFin, {|x| IF( AllTrim(x[1])==AllTrim(aPgtosSint[nX][1]),aAdd(aAdminist, x[3] + " - " + Capital(x[2])),Nil) } )

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Identifica se alguma das administradoras controla vale compras        ³
			//³ (AE_VCOMPRA = SIM). Se afirmativo, habilita a tela para a digitacao   ³
			//³ dos vales-compras, caso negativo, mantem a tela so' com a ADM.        ³
			//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
			//³ IMPORTANTE: So faz este controle caso o parametro MV_LJUSAFD esteja   ³
			//³ ativo e se existir o campo AE_VCOMPRA                                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lUsafd .AND. SAE->( FieldPos( "AE_VCOMPRA" ) ) > 0
				lControlaVale := .F.	// Define lControlaVale como falso por DEFAULT
				nZ := 1					// Inicializa o contador do looping
				While nZ <= Len( aAdminist ) .AND. !lControlaVale
					cCodAdmin := PadR( Substr(aAdminist[nZ],1,3), nTamAE_COD )
					If Posicione( "SAE", 1, xFilial("SAE") + cCodAdmin, "SAE->AE_VCOMPRA" ) == "1"
						lControlaVale := .T.
					EndIf
					nZ ++
				End
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
            //³A tela de solicitaçaõ de ADM poderá ser exibida nos seg. casos:		  ³
			//³1. TEF Discado, pois utilizamos esta inf. para chamar o software da ADM³
			//³2. lUsaTEF estiver falso, ele solicita o número para gravação          ³
			//³3. Se o parâmetro LJSLFIN estiver como verdadeiro                      ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			lCheckParc  := (AllTrim(aPgtosSint[nX][1]) $ cMV_PRXPARC) .And. Len(aAdmsFinRG) == 0
            // Teste de seleção da janela de administradora Financeira, para as formas que não retornem automaticamente pelo TEF
            lSelAdmin := (lInibirAdmF .And. !Empty(cMvFormaFi).And. aPgtosSint[nX][1] $ cMvFormaFi)

			If lUsaTef .AND. cTipTef <> TEF_DISCADO .AND. !GetNewPar("MV_LJSLFIN", .T.) .And. !lSelAdmin .AND. !lTemValeP

				aDadosAdm[1][1] 	:= aPgtosSint[nX][3] 				//Valor
				aDadosAdm[1][2] 	:= aPgtosSint[nX][5] 				//Data
				aDadosAdm[1][3] 	:= StrZero(aPgtosSint[nX][2],2,0) 	//Parcela
				aDadosAdm[1][5] 	:= ""								//Administradora
				aDadosAdm[1][6] 	:= lCheckParc						//Utiliza nas próximas parcelas
				aDadosAdm[1][7] 	:= AllTrim(aPgtosSint[nX][4])		//Sequencia para controle das multiplas transacoes
				aPgtosSint[nX][6]	:= aClone(aDadosAdm[1])				//Dados da Adm
				nx++

				lCancela := .F.
				lBotaoOk := .T.

			ElseIf Len(aAdminist) > 0

				nCont := 1
				lBotaoOk := .F.

				aDadosAdm[1][1] 	:= aPgtosSint[nX][3]				//Valor
				aDadosAdm[1][2] 	:= aPgtosSint[nX][5]				//Data
				aDadosAdm[1][3] 	:= StrZero(aPgtosSint[nX][2],2,0)	//Parcela
				aDadosAdm[1][5]		:= cCodAdmin
				aDadosAdm[1][6] 	:= lCheckParc						//Utiliza nas próximas parcelas
				aDadosAdm[1][7] 	:= AllTrim(aPgtosSint[nX][4])

				If nLjPagto == 2
					aDadosAdm[1][13]	:= AllTrim( SAE->AE_DESC ) // Descricao da Forma
					aDadosAdm[1][14]	:= aPgtosSint[nX][1] // Tipo da Forma
				EndIf

				If (lMVTELAFIN .OR. (!LJProfile(2) .AND. lSLGUCTef ) .OR. lControlaVale .OR. aPgtosSint[nX][1] $ cFormVale .OR. lSelAdmin) .AND.  (Empty(aPgtosSint[nX][6]))
					// Para Argentina a forma DC e tratada como conta corrente
					// por isso nao solicitamos a administradora financeira
					If cPaisLoc <> "ARG" .OR. ( cPaisLoc == "ARG" .AND. aPgtosSint[nX][1] <> "DC" )
						lJaSelec := .F.
						For nY := 1 to Len(aTefBKP)
							If	aPgtosSint[nX][1] 		== aTefBKP[nY]:CFORMA	 .AND.;
								aPgtosSint[nX][2]		== aTefBKP[nY]:NPARCELAS .AND.;
								Val(StrTran(aPgtosSint[nX][3],",","."))	== aTefBKP[nY]:NVLRTRANS .AND.;
								aPgtosSint[nX][4] 		== aTefBKP[nY]:CIDCART	 .AND.;
							 	aPgtosSint[nX][5]		== aTefBKP[nY]:DENTRADA

								If !Empty(aPgtosSint[nX][6])
									aDadosAdm[1] := aClone(aPgtosSint[nX][6])
									lJaSelec 	 := .T.
								EndIf
							EndIf
						Next nX

                        If ( !lJob .AND. lSelAdmin ) .OR.( !lJob .AND. (!lInibirAdmF .OR. lTemValeP) .AND. !lJaSelec )    
							LJ7TelaFin(	lControlaVale	, oDlgAdm	 	, @aDadosAdm	, aFontes		, ;
										lUsaTef			, nTamAE_COD 	, @oGetDad		, @bActionBt1	, ;
										@bActionBt2		, @aHeaderMAV	, @aColsMAV		, @lBotaoOK		, ;
										oBt1			, oBt2			, aAdminist 	, @lCancela		, ;
										@aVales			, @aTaxJuros	, aPgtosSint[nX][1]	)
						Else
                            If ExistBlock("LJ7028") .And. !lJob
                                cRetLJ7028 := ExecBlock("LJ7028",.F.,.F.,{aPgtosSint[nX][1], Val(aDadosAdm[1][1]), aDadosAdm[1][2], aDadosAdm[1][3], aDadosAdm[1][5]})
                                If !Empty(cRetLJ7028)
                                    cCodAdmin := PadR(cRetLJ7028,nTamAE_COD)
                                    aDadosAdm[1][5]	:= cCodAdmin
                                EndIf
                            EndIf
							lCancela := .F.
							lBotaoOk := .T.
						Endif
					Else
						lCancela := .F.
						lBotaoOk := .T.
					EndIf
				Else
                    If ExistBlock("LJ7028") .And. !lJob
                        cRetLJ7028 := ExecBlock("LJ7028",.F.,.F.,{aPgtosSint[nX][1], Val(aDadosAdm[1][1]), aDadosAdm[1][2], aDadosAdm[1][3], aDadosAdm[1][5]})
                        If !Empty(cRetLJ7028)
                            cCodAdmin := PadR(cRetLJ7028,nTamAE_COD)
                            aDadosAdm[1][5]	:= cCodAdmin
                        EndIf
                    EndIf
					lCancela := .F.
					lBotaoOk := .T.
				EndIf

				If !lCancela .AND. lBotaoOk
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Gravando a sequencia como dígígito do cartão, antigamente era digitado³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If aDadosAdm[1][6]  // Posicao do Check-Box Proximas Parcelas
						For nCont := nX To Len(aPgtosSint)
							If AllTrim(aPgtosSint[nCont][1]) == AllTrim(aPgtosSint[nX][1])
								aDadosAdm[1][7] := AllTrim(aPgtosSint[nCont][4])
								aPgtosSint[nCont][6] := aClone(aDadosAdm[1])
							EndIf
						Next nCont
						aDadosAdm[2][4] := Space(nTamL4_NUM)
					Else
						aDadosAdm[1][7]   := AllTrim(aPgtosSint[nX][4])
						aPgtosSint[nX][6] := aClone(aDadosAdm[1])
					EndIf
					nX ++
					aTx_Juros := aClone(aTaxJuros)
				EndIf
			Else
			   cDescri := AllTrim(Tabela("24",AllTrim(aPgtosSint[nX][1]),.F.))
			   //"Não há nenhuma Administradora Financeira cadastrada para a forma de pagamento "
				If !lAutoExB
					MsgStop(STR0112+cDescri)
				Else
					ConOut(STR0112+cDescri)
				EndIf
			   lCancela  := .T.
			EndIf
		Else
			nX ++
		EndIf
	End
EndIf

aTaxJuros := aClone(aTx_Juros)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se os cheques informados jah existem na base de dados         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ


cMens := ""
If !lCancela .AND. lBotaoOk
	For nX := 1 to Len( aAux )
		If AllTrim(aAux[nX][3]) == AllTrim(MVCHEQUE)
			If Valtype( aAux[nX][4] ) == "A" .AND. Len( aAux[nX][4] ) > 0
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ FILIAL + BANC0 + AGENCIA + CONTA + NUM³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				SEF->(DbSetOrder(1))
				If SEF->(DbSeek( xFilial("SEF")+aAux[nX][4][4]+aAux[nX][4][5]+aAux[nX][4][6]+aAux[nX][4][7] ))
					cMens += STR0097 + AllTrim(aAux[nX][4][4]) + "' "		//"Banco: '"
					cMens += STR0098 + AllTrim(aAux[nX][4][5]) + "' "		//"Agencia: '"
					cMens += STR0099 + AllTrim(aAux[nX][4][6]) + "' "		//"Conta: '"
					cMens += STR0100 + AllTrim(aAux[nX][4][7]) + "' "		//"Número: '"
					cMens += CRLF
				EndIf
			EndIf
		EndIf
	Next nX
EndIf

If !Empty( cMens )
	If lAutoExB .Or. (!lAutoExB .And. MsgYesNo( STR0101 + CRLF + cMens ))	//"Os cheques abaixo já estão gravados na base de dados, deseja corrigir as informações ?"
		aEval( aAux, { |x| If( AllTrim(x[3])==AllTrim(MVCHEQUE), (x[4]:={}),Nil) } )
		lCancela := .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Alimenta o array aPgtos com os dados do cheque , financeira ou cartao fidelidade    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lCancela .AND. lBotaoOk
	If !lVisuSint
		For nX := 1 to Len(aAux)
			If !IsMoney(aAux[nX][3])
				aPgtos[aAux[nX][5]][4] := aClone( aAux[nX][4] )
			EndIf
		Next nX
	Else
		For nX := 1 to Len(aAux)
			If Trim(aAux[nX][3]) == Trim(MVCHEQUE)
				aPgtos[aAux[nX][5]][4] := aClone( aAux[nX][4] )
			Else
				nPos := Ascan(aPgtosSint, { |x| ( AllTrim(x[1]) == AllTrim(aAux[nX][3]) .AND. AllTrim(x[4]) == AllTrim(aAux[nX][8]) ) })
				If nPos > 0 .OR. Empty(aAux[nX][4])
					aPgtos[aAux[nX][5]][4] := aClone( aPgtosSint[nPos][6] )
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Se existe desconto, no apgtos³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lLjDespa .AND. Len(aPgtos[aAux[nX][5]][4]) > 0 .AND.	aPgtos[aAux[nX][5]][4][9] > 0
						nTempDesc := 				(aPgtos[aAux[nX][5]][2] * aPgtos[aAux[nX][5]][4][9]) / 100
						nTempDesc := 				A410Arred(nTempDesc,"L2_VRUNIT")
						aPgtos[aAux[nX][5]][2] 	:= aPgtos[aAux[nX][5]][2] - nTempDesc
						aPgtos[aAux[nX][5]][4][1] 	:= cValToChar(aPgtos[aAux[nX][5]][4][9])
						If Empty(aPgtos[aAux[nX][5]][4][11])
							aPgtos[aAux[nX][5]][4][11] := PadR( Substr(aPgtos[aAux[nX][5]][4][5], 1,nTamAE_COD) , nTamBc )
						EndIf
						aPgtos[aAux[nX][5]][4][12] := nTempDesc
						nVlrDesc += nTempDesc
					EndIf
				ElseIf (!(AllTrim(aAux[1][3]) == "FI") .AND. Empty(aAux[nX][4]))
					aPgtos[aAux[nX][5]][4] := {}
				EndIf
			EndIf
		Next nX
	EndIf
EndIf


If lLjDespa
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta os valores de desconto (valor e percentual)           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7T_DescV( 2, nVlrDesc )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta o valor Total da venda                                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7T_Total( 2, LJ7T_Total(2) - nVlrDesc )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de entrada para validacao das informacoes digitadas de CC/CD/CH  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLJ7021 .AND. !lFtvdVer12
	lCancela := ExecBlock("LJ7021",.F.,.F.,{lCancela, nTipo})
	If Valtype(	lCancela) == "L"
		If lCancela
			For nF := 1 To Len(aPgtos)
				If AllTrim(UPPER(aPgtos[nF][3]))== "CH"
					aPgtos[nF][4] := {}
				EndIf
			Next nF
		EndIf
	Else
		lCancela := .F.
	EndIF
EndIf

If lFTVD7021 .AND. lFtvdVer12
	lCancela := ExecBlock("FTVD7021",.F.,.F.,{lCancela, nTipo})
	If Valtype(	lCancela) == "L"
		If lCancela
			For nF := 1 To Len(aPgtos)
				If AllTrim(UPPER(aPgtos[nF][3]))== "CH"
					aPgtos[nF][4] := {}
				EndIf
			Next nF
		EndIf
	Else
		lCancela := .F.
	EndIF
EndIf


If !lJob

	aAdmFinanc := aClone(aBkpAdmFin)

EndIf

Return !lCancela

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7CtrValeºAutor  ³ Vendas Clientes    º Data ³  05/12/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Faz a verificacao do(s) vale(s) compra(s) digitado         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ aGdados: Recebe a Get dados com os vales compras digitados º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CtrVale( aGdados )
Local lRet 			:= .T.				//Retorno da funcao
Local nTotVale		:= 0   				//Total de Vale Informado no aPagtos
Local nTotValeDig   := 0       			//Total de Vale-Compra digitado
Local nTotVen		:= 0				//Total da Venda
Local nX			:= 0             	//Contador
Local lAutoExB 		:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Soma o total de vale-compra informado na tela de pagamento³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX:= 1 to Len( aPgtos )
	nTotVen	+= aPgtos[nX][2]
	If aPgtos[nX][3] =="VA"
		nTotVale += aPgtos[nX][2]
	EndIf
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz a somatoria dos Vale-Compras informados.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX:= 1 to Len( aGdados )
	If !aGdados[nX][Len(aGdados[nx])]
		nTotValeDig += aGdados[nX][2]
	EndIf
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Nao permitir o fechamento da venda se o total de vales digitados,³
//³for menor que o total  informado na tela de pagamento.           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If  nTotVale > nTotValeDig
	If !lAutoExB
		aViso(STR0006, STR0146 , { STR0003 } )  //"Forma Pagto","Valor de Vale-Compra menor que o informado na condição de pagamento.", "OK"
	Else
		ConOut(STR0146)
	EndIf
	lRet:= .F.
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica se a diferenca entre o pagamento com vale-compra e³
	//³o total da compra esta dentro da diferenca permitida.      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	lRet := Crd240TvendXTvale(aGdados, nTotVen, nTotValeDig )
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7PesqValeºAutor  ³ Vendas Clientes    º Data ³ 06/12/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se o codigo do vale ja foi digitado               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7PesqVale()

Local nX		:= 0
Local lRet		:= .T.
Local cCodVale	:= M->MAV_CODIGO
Local nValor	:= 0
Local dValidade
Local oWs
Local lAutoExB	:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao
Local lMVLJPDVPA:= FindFunction("LjxBGetPaf") .AND. LjxBGetPaf()[2] 					//Indica se é pdv


If nModulo == 23 .OR. lMVLJPDVPA

	oWs := WSFRTCRDPSVPG():New()
	oWs :_URL := "http://"+AllTrim(LJGetStation("WSSRV"))+"/FRTCRDPSVPG.apw"


	oWs:CrdPSVcPg(cCodVale) //"Executando consulta na retaguarda"
	lRet := oWs:OWSCrdPSVcPgRESULT:OWSLSVC[1]:lRet

	If lRet
		aCols[n,2] 	:=	oWs:OWSCrdPSVcPgRESULT:OWSLSVC[1]:nValor
		aCols[n,3] 	:=	oWs:OWSCrdPSVcPgRESULT:OWSLSVC[1]:dValidade
	EndIf

Else
	For nX:= 1 to Len( aCols )

		If aCols[nX][1] == cCodVale
			If !lAutoExB
				aViso(STR0113, STR0114 , {"OK"} ) //"Nro Vale Compra"/"Numero ja ditado. Informe outro numero."
			Else
				ConOut(STR0114)
			EndIf
			lRet := .F.
			Exit
		EndIf
	Next nX

	If lRet
		lRet := Crd240ValidUsoVale( cCodVale, "2", @nValor, @dValidade )
		If lRet
			aCols[n,2] := nValor
			If MAV->( FieldPos( "MAV_DTVALI" ) ) > 0
				 aCols[n,3]:= dValidade
			EndIf
		EndIf

	EndIf
EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7CondNegºAutor  ³ Vendas Clientes    º Data ³  17/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Chamada do botao de condicao negociada                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpO1 - Painel da condicao negociada(objeto)                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7CondNeg(oPanCondNeg)
Local lLj7004		:= ExistBlock("LJ7004")
Local aRet 			:= {}
Local nX			:= 0
Local nVlrAux 		:= 0
Local nVlrParcelas	:= 0
Local cLj7015
Local lAutoExB		:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao
Local cFTVD7015
Local lFTVD7004		:= ExistBlock("FTVD7004")
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

If ExistBlock("LJ7015") .AND. !lFtvdVer12
	cLj7015 := ExecBlock("LJ7015", .F., .F., {lRecebe,"CN"})
	If !(Empty(cLJ7015) .OR. 'CN' $ cLj7015)
		Return(NIL)
	EndIf
EndIf

If ExistBlock("FTVD7015") .AND. lFtvdVer12
	cFTVD7015 := ExecBlock("FTVD7015", .F., .F., {lRecebe,"CN"})
	If !(Empty(cFTVD7015) .OR. 'CN' $ cFTVD7015)
		Return(NIL)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se existe o ponto de entrada, caso contrario chama a rotina   ³
//³padrao da condicao negociada                                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nVlrAux := Lj7T_Total( 2 )
If (lLj7004 .AND. !lFtvdVer12) .OR. (lFTVD7004 .AND. lFtvdVer12)
	If !lFtvdVer12
	aRet := ExecBlock('LJ7004',.F.,.F.)
	ElseIf lFtvdVer12
		aRet := ExecBlock('FTVD7004',.F.,.F.)
	EndIf
	If ValType( aRet ) == "A"
		If Len(aRet) > 0
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Zera o array aPgtos para gravar o novo calculo³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			aPgtos := {}
			For nX := 1 to Len(aRet)
				If Len(aRet[nX]) > 3 .AND. ValType(aRet[nX][4]) == "A" .AND. (Len(aRet[nX][4]) == 7 .OR. Len(aRet[nX][4]) == 12)
					aAdd( aPgtos, { aRet[nX][1],;
									aRet[nX][2],;
									aRet[nX][3],;
									aRet[nX][4],;
									NIL,;
									If(cPaisLoc <>" BRA", nMoedaCor, 1),;
					                If(cPaisLoc <> "BRA", aRet[nX][1], NIL),;
					                If(lVisuSint, SL4->L4_FORMAID, Space(01)),;
					                Space(01),;
					                0 } )
				Else
					aAdd( aPgtos, { aRet[nX][1],;
									aRet[nX][2],;
									aRet[nX][3],;
									{},;
									NIL,;
									If(cPaisLoc <> "BRA", nMoedaCor, 1),;
				                	If(cPaisLoc <> "BRA", aRet[nX][1], NIL),;
				                	If(lVisuSint, SL4->L4_FORMAID, Space(01)),;
				                	Space(01),;
				                	0 } )
				EndIf
				nVlrParcelas += aRet[nX][2]
			Next nX
			If lVisuSint
				aPgtosSint := Lj7MontPgt(aPgtos)
				oPgtosSint:SetArray( aPgtosSint )
				oPgtosSint:Refresh()
			EndIf
			oPgtos:SetArray( aPgtos )
			oPgtos:Refresh()
			Lj7T_Total( 2, If(nVlrParcelas>nVlrAux,nVlrParcelas,nVlrAux) )

			LJ7AjustaTroco()

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Ajusta os valores de PIS/COFINS caso Haja                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7PisCof()
		EndIf
	EndIf
Else
	If LjProfile(9) .AND. VerSenha(46)
		oPanCondNeg:Show()
		oPanCondNeg:lReadOnly := .F.
	Else
		If !lAutoExB
			MsgStop(STR0072) //'Caixa não autorizado.'
		Else
			ConOut(STR0072) //'Caixa não autorizado.'
		EndIf
	EndIf
EndIf

Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7AjustaTºAutor  ³ Vendas Clientes    º Data ³  17/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz o ajuste do troco e do valor das parcelas na tela       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpL1 - Determina que a função esta sendo chamada da rotina º±±
±±º          ³        de gravacao do orçamento. Nesse caso para localiza- º±±
±±º          ³        coes eh necessário realizar um tratamento diferen-  º±±
±±º          ³        ciado para o troco.                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7AjustaTroco(lGrvOrc,cCondPagto,cFormPagto)
Local nVlrParcelas	:= nNCCUsada        	// Valor das Pacelas
Local nVlrTotal     := LJ7T_Total(2)		// Valor Total
Local nVlrTroco		:= 0					// Valor do troco
Local nI            := 0					// Variavel contador de loop
Local lTrocoPad     := .T.					// Variavel logica de troco

Default lGrvOrc 	:= .F.
Default cFormPagto	:= Nil 					// Forma de Pagamento
Default cCondPagto	:= Nil 					// Condicao de Pagamento (SE4)

If MaFisFound("NF") .And. MaFisRet(,'NF_VALISS') > 0
	//Ajusta o Valor caso tenha Abatimento de ISS
	If ( !Empty(cCondPagto) .Or. !Empty(cFormPagto) ) .And. LjxDAbISS(cCondPagto,cFormPagto,MaFisRet(,'NF_VALISS'))
		nVlrTotal -= MaFisRet(,'NF_VALISS')
	EndIf
EndIf

If FindFunction("LjxBGetPaf") .AND. LjxBGetPaf()[2]
	nVlrParcelas := Frt060Ret("NCC_USADA")
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz o ajuste das variaveis de total das parcelas e troco considerando a NCC Usada ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc == "BRA"
   aEval( aPgtos, {|x| nVlrParcelas+=x[2] })
Else
   aEval( aPgtos, {|x| nVlrParcelas+=Round(xMoeda(x[2],x[_MOEDA],nMoedaCor,dDatabase,nDecimais+1,,nTxMoeda),nDecimais)})
	//Determina que o orçamento esta sendo gravado. O troco nao deve ser recalculado...
	If SuperGetMV("MV_LJTRLOC")
		If !lGrvOrc
			//Monta o Array para o calculo do troco...
			If (nVlrParcelas > Lj7T_Total(2))
				// Colocado esta validacao pois em alguns clientes o focus se perder e quando
				// acionado a tecla de finalizacao como orcamento,o sistema trava.
				If ValType(oPgtos) == "O"
				    oPgtos:SetFocus()
				EndIf
				// Valida se o objeto ja existe.
				If ValType(oLBBaixa) == "O"
					oLBBaixa:Show()
					oPgtos:nHeight := (_nHeight-70)
					CalcValTrc(Lj7T_Total(2),aPgtos, cSimbCheq , @aMoedas,;
							   @aTroco      ,4     , nNCCUsada )
					// Retorna a moeda que sera informado o troco da venda
					If ExistBlock("LJ7076")
					    aMoedas:=ExecBlock("LJ7076",.F.,.F.)
					Endif
				EndIf
			Else
				If (Type("oLBBaixa") == "O") .AND. (oLBBaixa:lVisible)
					oLBBaixa:Hide()
					oPgtos:nHeight := _nHeight
				EndIf
			EndIf
		Else
			For nI := 1 To Len(aMoedas)
				If aMoedas[nI][03] <> 0
					lTrocoPad := .F.
					Exit
				EndIf
			Next nI
			If Lj7T_Troco(2) > 0 .AND. nVlrTroco == 0
				nVlrTroco := Lj7T_Troco(2)
			EndIf
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Adiciona o valor do frete no total                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( M->LQ_TPFRET == "2" .AND. MaFisFound("NF") .AND. cPaisLoc == "BRA" .AND. lCalcFrete ) .Or. If(Type("lAutoExec") <> "U",lAutoExec ,.F.)
	nVlrTotal += Lj7CalcFrete()
	lCalcFrete := .F. //Seta a variavel para .F. para que nao seja somado novamente o valor do frete no valor total
EndIf

If nVlrParcelas >= nVlrTotal .AND. lTrocoPad
	If !((nVlrParcelas - nVlrTotal) > 0 .And. aAcrescimo[1] > 0 .And. (aAcrescimo[1] == (nVlrParcelas - nVlrTotal)))
		nVlrTroco 	:= ( nVlrParcelas - nVlrTotal )
	EndIf
EndIf

If nVlrTroco = 0
	//Zera a forma de pagamento associada ao troco
	Lj7SetTrcForm("")
EndIf

Lj7T_Troco( 2, nVlrTroco )
Lj7T_TotPar( 2, nVlrParcelas )

Return nVlrTroco

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7PisCof ºAutor  ³ Vendas Clientes    º Data ³ 11/05/2004  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz o ajuste dos valores de PIS/COFINS para os totalizadoresº±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7PisCof(cCondPagto,cFormPagto)

Local nVlrParcelas	:= 0 															// Valor Total das parcelas
Local nVlrTotal     := Lj7T_Total( 2 )                 								// Valor Total
Local nPosValISS	:= aScan(aHeaderDet, { |x| AllTrim(x[02]) == "LR_VALISS" })	// Posicao do elemento LR_VALISS no array acolsdet
Local nPosTES		:= aScan(aHeaderDet, { |x| AllTrim(x[02]) == "LR_TES" })		// Posicao do elemento LR_TES no array acolsdet
Local nSumValISS	:= 0 															// Acumula o total do ISS contido no acolsdet na posicao LR_VALICM
Local nX  			:= 0															// Contador para o Loop que soma os registros com ISS

Default cCondPagto 	:= Nil
Default cFormPagto	:= Nil

If MaFisFound()
	If nVlrTotal > 0 .And. MaFisRet(,'NF_VALISS') > 0
		If (!Empty(cCondPagto) .Or. !Empty(cFormPagto)) .AND. LjxDAbISS(cCondPagto,cFormPagto,MaFisRet(,'NF_VALISS'))
			nVlrTotal -= MaFisRet(,'NF_VALISS')
		EndIf
	EndIf
	nVlrParcelas	:= Lj7T_TotPar(2)
Else
	For nX := 1 To Len(aColsDet)
		If !aColsDet[nX][Len(aColsDet[nX])]
			If Posicione("SF4", 1, xFilial("SF4") + PadR(aColsDet[nX][nPosTES], TamSx3("F4_CODIGO")[1]), "SF4->F4_ISS") == "S"	//Se for Servico
				nSumValISS += aColsDet[nX][nPosValISS]
			EndIf
		EndIf
	Next nX
	nVlrParcelas	:= Lj7T_TotPar(2) + If( LJ220AbISS(), nSumValISS, 0 )
EndIf

// Verifico se o sistema possui valor de PIS/COFINS
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Regra para o cAlculo do PIS/COFINS/CSLL                                            ³
//³=======================================                                            ³
//³O calculo podera ser realizado de duas formas:                                     ³
//³                                                                                   ³
//³1) Por Apuracao: Neste caso e` rodado no faturamento um programa                   ³
//³para fazer a apuracao dos impostos: L2_VALPS2,  L2_VALCF2 etc                      ³
//³Na venda o sistema verifica se a TES calcula PIS/COFINS/CSLL e alimenta            ³
//³os campos referente a estes impostos na tabela SL2.                                ³
//³                                                                                   ³
//³2) Por Retencao: Neste caso o calculo e` realizado na emissão da nota;             ³
//³Regra para retenção:                                                               ³
//³====================                                                               ³
//³Criar uma natureza que calcule PIS/COFINS/CSLL;         							  ³
//³Amarrar esta natureza no cadastro do cliente;                                      ³
//³Preencher um ou todos os Campos:A1_RECPIS, A1_RECCOF e A1_RECCSLL com o valor "SIM"³
//³                                                                                   ³
//³Importante: Para Retencao, somente sera calculado os impostos se o produto tambem  ³
//³ Tiver retencao de PIS/COFINS/CSLL.                                                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If	SA1->A1_RECPIS  == "S" .OR. ;
	SA1->A1_RECCOFI == "S" .OR. ;
	SA1->A1_RECCSLL == "S" .OR. ;
	( Iif(FindFunction('lj7RecISS'),Lj7recIss(), SA1->A1_RECISS == "1" .AND. GetNewPar("MV_DESCISS", .F.)) )

	Lj7T_TotPar( 2, nVlrParcelas)

	If nVlrParcelas >= nVlrTotal
		Lj7T_Troco(  2, nVlrParcelas - nVlrTotal  )
	EndIf
EndIf

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7SeleNCCºAutor  ³ Vendas Clientes    º Data ³  24/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a selecao das NCCs a serem usadas.                      º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso		 ³ LOJA701 													  º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7SeleNCC(nOpc)
Local oOk       := LoadBitmap( GetResources(), "LBOK" )								// Objeto do botao OK
Local oNo       := LoadBitmap( GetResources(), "LBNO" )	   							// Objeto do botao cancela
Local cCliente  := M->LQ_CLIENTE													// Cliente corrente
Local cLoja     := M->LQ_LOJA														// Loja corrente
Local nVlrParc	:= 0 																// Valor das parcelas
Local lLj7026   := (ExistBlock("LJ7026"))				   							// Ponto de entrada para selecao de NCC
Local cMVCliPad := SuperGetMV("MV_CLIPAD") 											// Cliente padrao
Local cMVLojaPad:= SuperGetMV("MV_LOJAPAD")											// Loja Padrao
Local nNccUsaBkp:= If(nNCCUsada > 0,nNCCUsada , 0 )									// Guarda a Ncc que ja foi selecionada
Local nPosEnvelo:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ENVELO"})		// Posicao do campo com o codigo o envelope no aColsDet
Local nCont     := 1                                                                // Contador auxiliar para FOR.
Local lVldNCC   := .F.									   							// Indica se valida vencimento da NCC
Local bValBlock := Nil																// Bloco para validacao de vencimento da NCC
Local cQuery  	:= ""
Local cAliasSE1 := "SE1"
Local lAchouSE1 := .F.
Local aAuxIN  	:= StrToArray(AllTrim(MV_CRNEG), Iif( MV_CRNEG $",", ",", "|"))     // Do parametro (MV_CRNEG) vem separado por "," / da tabela SES vem separado com "|"
Local cMVCRNegIN:= ""
Local nTamTIPO	:= TamSx3("E1_TIPO")[1]
Local cFilSE1 	:= xFilial("SE1")
Local bWhile 	:= {|| .F. }
Local lQuery 	:= .F.
Local lLjNCCOr	:= SuperGetMv("MV_LJNCCOR", Nil, .F.)  //verifica se a NCC sera mantida no orcamento (F4)
Local cNumOrc 	:= M->LQ_NUM
Local lCmpNcc   := .F.
Local lPaf      := LjNfPafEcf(SM0->M0_CGC)
Local lFTVD7026 := (ExistBlock("FTVD7026"))					// Ponto de entrada para selecao de NCC
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default nOpc 	:= 0

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita as teclas de atalho                                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7SetKeys(.F.)

aEval(aAuxIN, { |x| cMVCRNegIN += "'"+PadR(x,nTamTIPO)+"'," })
cMVCRNegIN := Left( cMVCRNegIN, Len(cMVCRNegIN)-1 )
If Empty(cMVCRNegIN)
	cMVCRNegIN := "' '"
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³	Alimenta variavel de validacao da validade na NCC³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lVldNCC := SuperGetMV("MV_LJVLNCC",,.F.)

If Substr(SuperGetMV("MV_USACRED"),2,1) == "S"
	aNCCItens := {}
	nNCCUsada := 0
	Lj7AjustaTroco()
	If Len(aNCCItens) == 0
		If (lLj7026 .AND. !lFtvdVer12) .OR. (lFTVD7026 .AND. lFtvdVer12)
			/*Permite adcionar as NCC's conforme uma regra de negocio do cliente */
			If!lFtvdVer12
				LjGrvLog( NIL, "Antes da execução do P.E. LJ7026", {nOpc,aNccItens})
                ExecBlock("LJ7026", .F., .F., {nOpc})
                LjGrvLog( NIL, "Depois da execução do P.E. LJ7026", {nOpc,aNccItens})
			ElseIf lFtvdVer12
				LjGrvLog( NIL, "Antes da execução do P.E. FTVD7026", {aNccItens})
				ExecBlock("FTVD7026", .F., .F.)
				LjGrvLog( NIL, "Depois da execução do P.E. FTVD7026", {aNccItens})
			EndIf
			
			If (ValType( aNccItens ) == "A") .And. (Len(aNccItens) > 0)
				LjGrvLog( NIL, " Retorno do P.E. conforme esperado - variavel do tipo lógico")
				If lLjNCCOr .AND. nOpc == 4 .And. (!lPaf .Or. lFtvdVer12) //Para ambiente (SIGALOJA on-Line),finalizacao da venda
					lCmpNcc := .T.
				EndIf
			EndIf
	    Else
	    	If (Alltrim(cMVLojaPad) + Alltrim(cMVCliPad)) <> (Alltrim(cLoja) + Alltrim(cCliente))
	    		SE1->(DbSetOrder(8)) //E1_FILIAL, E1_CLIENTE, E1_LOJA, E1_STATUS, E1_VENCREA

				#IFDEF TOP
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Verificar se eh AS/400, pois a coluna R_E_C_N_O_ nao existe em AS/400³
					//³dessa forma a condicao sera a do codebase.                           ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If ( TcSrvType()<>"AS/400" )
						lQuery := .T.
						cAliasSE1 := "NCCFILSE1"

                        cQuery := "SELECT E1_CLIENTE, E1_LOJA, E1_TIPO, E1_STATUS, SE1.R_E_C_N_O_ RECSE1"
                        
                        If lLjNCCOr .AND. nOpc == 4 .And. (!lPaf .Or. lFtvdVer12 ) //Para ambiente (SIGALOJA on-Line),finalizacao da venda
                            cQuery += "  , MDJ_NUMORC as SELMDJORC "
                            lCmpNcc := .T.
                        EndIf
                        
                        cQuery += "  FROM " + RetSQLName("SE1") + " SE1 "

                        //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                        //³Se o parametro estiver habilitado retonar somente as NCC's definidas ³
                        //³no orcamento, se for venda avulsa (sem orcamento) trara as NCC's     ³
                        //³do cliente.                                                          ³
                        //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ                        
                        If lCmpNcc
                            cQuery += " LEFT JOIN " + RetSQLName("MDK") + " MDK ON  MDK.MDK_NUMREC = SE1.R_E_C_N_O_ AND MDK.D_E_L_E_T_ = ' ' "
                            cQuery += " LEFT JOIN " + RetSQLName("MDJ") + " MDJ ON MDJ.MDJ_FILIAL = MDK.MDK_FILIAL AND MDJ.D_E_L_E_T_ = ' ' "
                            cQuery += " AND MDJ.MDJ_NUMORC = MDK.MDK_NUMORC "
                            cQuery += "  AND MDJ.MDJ_SITUA = 'OR' AND MDJ.MDJ_NUMORC = '" + Alltrim(cNumOrc) +  "' "
                        EndIf

                        cQuery += " WHERE "
                        If !SuperGetMV("MV_LJNCCFI",,.F.)
                            cQuery += "   E1_FILIAL  = '"+cFilSE1+"' AND "
                        EndIf
                        cQuery += "   E1_CLIENTE = '"+cCliente+"' AND "
                        If !SuperGetMV("MV_LJNCCLJ",,.F.)
                            cQuery += "   E1_LOJA    = '"+cLoja+"' AND "
                        EndIf
                        cQuery += "   E1_STATUS  = 'A' AND " //A=Em Aberto
                        If Len(aAuxIN) > 1
                            cQuery += "   E1_TIPO IN ("+cMVCRNegIN+") AND "
                        Else
                            cQuery += "   E1_TIPO = "+cMVCRNegIN + " AND "
                        EndIf
                        cQuery += "   SE1.D_E_L_E_T_ = ' ' "

						cQuery := ChangeQuery(cQuery)
						dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),cAliasSE1,.F.,.F.)

						lAchouSE1 := (cAliasSE1)->( !EoF() )
						bWhile 	  := {|| !(cAliasSE1)->(EOF()) }
					Else
				#ENDIF
					lAchouSE1 := SE1->(DbSeek(cFilSE1+cCliente+cLoja+"A"))
					bWhile 	  := {|| !(cAliasSE1)->(EOF()) .AND. ((cAliasSE1)->(E1_FILIAL+E1_CLIENTE+E1_LOJA) == cFilSE1+cCliente+cLoja) .AND. (cAliasSE1)->E1_STATUS == "A" }
				#IFDEF TOP
					Endif
				#ENDIF

				If lAchouSE1
					While Eval(bWhile)
						If (cAliasSE1)->E1_TIPO $ MV_CRNEG

							#IFDEF TOP
								If lQuery
									SE1->(DbGoTo((cAliasSE1)->RECSE1))
								EndIf
							#ENDIF

							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³	Verifica se usa validade na NCC. Se usar Valida	 ³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							bValBlock := IIf(lVldNCC, {||SE1->E1_VENCREA >= dDataBase}, {||.T.} )
							If Eval(bValBlock)

								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³SIGAPHOTO - Insere o valor de credito do consumidor caso o valor do SE1,³
								//³seja referente ao sinal de um envelope que estava no aCols.             ³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								If nModulo == 72
									If !Empty(SE1->E1_ENVELO)
										For nCont := 1 To Len(aColsDet)
									   		If AllTrim(aColsDet[nCont][nPosEnvelo]) == AllTrim(SE1->E1_ENVELO)

			   								    //Adiciona item no aNCCItens
												If ExistFunc("LjNCCItens")
													LjNCCItens(@aNCCItens, nTxMoeda)
												EndIf
									        EndIf
									    Next nCont
			    						(cAliasSE1)->(dbSkip())
			    						Loop
									EndIf
								EndIf

							    //Adiciona item no aNCCItens
								If ExistFunc("LjNCCItens")
									LjNCCItens(@aNCCItens, nTxMoeda,,,IIF(lCmpNcc,Alltrim((cAliasSE1)->SELMDJORC),""))
								EndIf
							EndIf
						EndIf
						(cAliasSE1)->(dbSkip())
					End
				EndIf

				#IFDEF TOP
					If lQuery
						(cAliasSE1)->( dbCloseArea() )
						dbSelectArea("SE1")
					EndIf
				#ENDIF

			EndIf
		EndIf
		If Len(aNCCItens) > 0
			aNCCItens := aSort(aNCCItens,,,{|x,y| x[4]<y[4]})
		EndIf
		SE1->(DbSetOrder(1))
	EndIf

	If Len(aNCCItens) > 0
        LjGrvLog(cNumOrc,"LISTA DE NCCs IMPORTADAS",aNCCItens)
        LjxDSelNCC(aNCCItens,"LOJ",NIL,nNCCUsada,nil,nOpc,lCmpNcc)
        LjGrvLog(cNumOrc,"NCC USADA depois da SELECAO",nNCCUsada)
	Else
		nNCCUsada := 0
	EndIf
	Lj7AjustaTroco()
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica se a NCC escolhida anteriormente depois de dar (F7)(F7) nao foi selecionada novamente ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If ( nNccUsaBkp > 0 ) .AND. ( nNccUsaBkp <> nNCCUsada )
		lDesSelNCC	:= .T.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Habilita as teclas de atalho                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7SetKeys(.T.)

Return NIL

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7VldCondºAutor  ³ Vendas Clientes    º Data ³  20/11/2002 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Validacao do código da condicao de pagamento digitada       º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701B                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7VldCond(cCond		, cDescCondPg	, oDescCondPg	, oPgtos,;
					cAlterCond	, nOpc			, nVlrAcrsFi	, lVldCondPg	)

Local lRet 			:= .T. 		   		//Retorno da funcao
Local bLostFocus 	:= {|| }
Local nVlrTot       := Lj7T_Total( 2 ) 	// Retorna o valor total da venda
Local lAltCond      := .F.				// Verifica se foi alterada a condicao de pagamento
Local lAutoExB		:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao
Local lDescCondPg   := (oDescCondPg <> NIL)//Verifica se o objeto oDescCondPg está setado, quando executado ExcAuto do módulo SIGAOFI nao vem setado
Local lPgtosSint    := (oPgtosSint <> Nil) //Verifica se o objeto oPgtosSint está setado, quando executado ExcAuto do módulo SIGAOFI nao vem setado
Local cReadVar		:= __ReadVar		//Backup da M->LQ_CONDPG
Local aTituloOri 	:= {} //Array com os dados do array statico "aTitulo" com os valores originais da rotina de Recebimento de Titulo
Local nPosTitOri 	:= 0
Local nVlrTitulo	:= 0
Local nVlDescTit 	:= 0
Local lLjGetaTit 	:= ExistFunc("LjxRecGTit")
Local nI		 	:= 0

Default nOpc 		:= 0
Default nVlrAcrsFi 	:= 0
DEFAULT cAlterCond	:= ""
Default lVldCondPg  := .T.

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ A variavel cCondSE4 foi criada para controlar a alteracao do objeto      ³
//³ oCondPg para saber quando ele foi realmente alterado ou quando so foi    ³
//³ passado o cursor sobre o campo.                                          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Static cCondSE4		:= ""
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se houve modificacoes no campo de condicao de pagamento³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If !Empty(Alltrim(cCondSE4)) .And. lVldCondPg
    lAltCond := cCond <> Alltrim(cCondSE4)
Else
    If !Empty(cCondAntX) .And. cCondAntX <> M->LQ_CONDPG
        ACO->(dbSetOrder(2))

        lAltCond := (!Empty(cCondAntX) .And. ACO->(dbSeek(xFilial("ACO") + cTabPad + cCondAntX)))
    EndIf
EndIf

If lAltCond .AND. IIf(cAlterCond <> Nil, cCond <> cAlterCond, .F.)
	nVlrAcrsFi := 0
EndIf

cAlterCond := cCond

If cCondSE4 == cCond
	bLostFocus := { || }
Else
	bLostFocus := { || ( If(!Empty(cCond),cDescCondPg := SE4->E4_DESCRI,Nil), IIf(lDescCondPg,oDescCondPg:Refresh(),NIL), M->LQ_TIPOJUR := 0,;
						Lj7CondPg( 2, cCond, Nil, Nil, Nil, Nil, Nil, Nil, nOpc, Nil,.T.,lAltCond, @nVlrAcrsFi,,lNovRegDesc),;
						If(lVisuSint,IIf(lPgtosSint,oPgtosSint:SetFocus(),Nil),IIf(lPgtosSint,oPgtos:SetFocus(),Nil)) ) }
	cCondSE4 := cCond
EndIf

If !Empty(cCond)
	If !Empty( Trim(SL1->L1_FILRES+SL1->L1_ORCRES) ) .AND. cCond <> SL1->L1_CONDPG
		If !lAutoExB
			Aviso( STR0001, STR0002,{STR0003} ) //'Atenção'###'Não é permitida a alteração das formas de pagamento de um orçamento gerado com reserva.'###'Ok'
		Else
			ConOut(STR0002)
		EndIf
		lRet := .F.
	EndIf
EndIf

If lRet
	SE4->(DbSetOrder(1))
	SE4->(DbSeek(xFilial("SE4")+cCond))
	Do Case
		Case nVlrTot > SE4->E4_SUPER .AND. SE4->E4_SUPER <> 0
			Help(" ","1","LJLIMSUPER")
			lRet := .F.
		Case nVlrTot < SE4->E4_INFER .AND. SE4->E4_INFER <> 0
			Help(" ","1","LJLIMINFER")
			lRet := .F.
    OtherWise
		If !isBlind()
			Eval( bLostFocus )
		EndIf

		cDescCondPg := Posicione("SE4",1,xFilial("SE4")+M->LQ_CONDPG,"SE4->E4_DESCRI")
		
		If oDescCondPg <> Nil
	    	oDescCondPg:Refresh()
	 	EndIf
    EndCase
EndIf

//Tratamento para atualizar informações após seleção ou troca da Condição de Pagamento
If lRet .And. lAltCond .And. !lRecebe
	__ReadVar := cReadVar
	Lj7AltCond()
    If aPgtos[1][2] == 0
        //Caso o aPgtos não ter sido atualizado, ja o atualizo aki, para evitar a chamada desnecessária do Lj7CondPg
        If !lAutoExB
        	LjGrvLog( NIL, " Validação da Condição - aPgtos", aPgtos)
            Lj7CondPg( 2, cCond, Nil, Nil, Nil, Nil, Nil, Nil, nOpc, Nil,.T.,.T., @nVlrAcrsFi,,lNovRegDesc)
            LjGrvLog( NIL, " Validação da Condição - Depois Lj7CondPg - aPgtos", aPgtos)
        EndIf       
    EndIf
EndIf 
       
If lRet .And. lRecebe .And. lLjGetaTit 
	If ExistFunc("LJ7E4DSCFI") //LOJXFUNC - Evitar que o valor total das parcelas fique menor que o total da venda por conta da %desconto financeiro
    	nDescFin := Lj7T_Subtotal(2) - (LJ7E4DscFi(Lj7T_Subtotal(2) - nNCCUsada , nOpc, lAltCond )+ nNCCUsada) //Verifica se SE4->E4_DESCFIN > 0
    EndIf        
    //Resgata o array statico aTitulo original do fonte LOJXREC
	aTituloOri := LjxRecGTit()
              
    //Reseta os valores originais de TOTAL e DESCONTO de cada titulo
    For nI := 1 To Len(aTitulo)
    	//Restaura os valores anteriores (tira o desconto financeiro)
    	If Len(aTituloOri) > 0 .And. ( nPosTitOri := aScan( aTituloOri, {|x| x[15]+x[02]+x[03]+x[04]+x[11] == aTitulo[nI][15]+aTitulo[nI][02]+aTitulo[nI][03]+aTitulo[nI][04]+aTitulo[nI][11] } ) ) > 0
        	aTitulo[nI][08] := aTituloOri[nPosTitOri][08]
        	aTitulo[nI][09] := aTituloOri[nPosTitOri][09]
        	aTitulo[nI][10] := aTituloOri[nPosTitOri][10]
    	Else
        	aTitulo[nI][10] := aTitulo[nI][10] + aTitulo[nI][09]
        	aTitulo[nI][09] := 0
    	EndIf
    	
    	nVlDescTit 	:= aTitulo[nI][09]
		nVlrTitulo	:= aTitulo[nI][10]
		
		If nDescFin > 0
			If nVlrTitulo > nDescFin
				nAuxDescFin := nDescFin
			Else
				nAuxDescFin := nVlrTitulo
			EndIf
			nDescFin -= nAuxDescFin
		Else
			nAuxDescFin := 0
		EndIf
		
		nVlDescTit := nVlDescTit + nAuxDescFin
		nVlrTitulo := nVlrTitulo - nAuxDescFin
		
		aTitulo[nI][09] := nVlDescTit
		aTitulo[nI][10] := nVlrTitulo     
		
		If nI == 1 .And. nVlrAcrsFi > 0  // Adiciona o acrescimo na primeira parcela 
			aTitulo[nI][08] := aTitulo[nI][08] + nVlrAcrsFi
			aTitulo[nI][10] += nVlrAcrsFi			
		EndIf
    Next nI        
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7TitBotoºAutor  ³ Vendas Clientes    º Data ³  21/11/2002 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Prepara os titulos dos botoes da tela de forma de pagamento º±±
±±º          ³e define tambem suas teclas de atalho                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701B - Montagem da tela de forma de pagamento           º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function Lj7TitBotoes(aFormPgtos, aTecAtalho, nPos)
Local cRet    := ""											//Retorno da Funcao
Local cTitulo := AllTrim(Capital(aFormPgtos[nPos][2]))		//Titulo do Botao
Local nX      := 0                                  		//Var. Auxiliar
Local cLetra  := ""                                 		//Letra que sera utilizada na tecla

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Na primeira vez, pega a primeira letra e coloca a tecla de atalho      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Empty( aTecAtalho )
	cRet := "&" + cTitulo
	AAdd(aTecAtalho,SubStr(Upper(cTitulo),1,1))
Else
	cRet := cTitulo
	For nX := 1 to Len(cTitulo)
		cLetra := SubStr(cTitulo,nX,1)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Se a letra selecionada nao possui atalho, utilizo e guardo para o proximo atalho³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If aScan(aTecAtalho,Upper(cLetra)) == 0
			If nX == 1
				cRet := "&" + cTitulo
			Else
				cRet := SubStr(cTitulo,1,AT(cLetra,cTitulo)-1) + "&" + SubStr(cTitulo,AT(cLetra,cTitulo))
			EndIf

			AAdd(aTecAtalho,Upper(cLetra))
			Exit
		EndIf
	Next nX
EndIf

Return cRet

/*/
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ LJ701BPAR     ³ Autor ³ Vendas Clientes  ³ Data ³ 17/05/03 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Seta o foco para o Get dos Ultimos 4 digitos do cartao qdo ³±±
±±³          ³ desabilitdo o CHECKBOX                                     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LJ701BPAR()                                                ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ EXPL1 - Array aDadosAdm ( Veja definicao no inicio do fonte³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ Sigaloja - Venda Assistida                                 ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function LJ701BPAR(aDadosAdm, oBt1)
If lUsaTef .AND. SuperGetMV("MV_TEFMULT")
   If !aDadosAdm[1][6]
       aDadosAdm[2][7]:SetFocus()
   Else
       oBt1:SetFocus()
       aDadosAdm[2][7]:Disable()
       aDadosAdm[2][7]:Refresh()
   EndIf
EndIf
Return( NIL )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7RecalImºAutor  ³ Vendas Clientes    º Data ³  08/01/2004 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao que recalcula os impostos variaveis(Localizacoes)   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1 - Item do array aColsDet que deve ser atualizado     º±±
±±º          ³ ExpN2 - Tipo de operacao que esta sendo realizada:         º±±
±±º          ³         1 - Troca de Cliente/Loja                          º±±
±±º          ³         2 - Alteracao do TES ou qualquer campo que necessi-º±±
±±º          ³             te recalculo dos impostos                      º±±
±±º          ³         3 - Inclusao de um novo item na venda              º±±
±±º          ³         4 - Exclusao de um Item                            º±±
±±º          ³         5 - Desmarca a delecao de Item                     º±±
±±º          ³ ExpC3 - Item que deve ser informado na função MaFisAlt.    º±±
±±º          ³         Ex: "IT_TES"                                       º±±
±±º          ³ ExpX4 - Conteudo do campo indicado no parametro ExpC3 para º±±
±±º          ³         a funcao MaFisAlt()                                º±±
±±º          ³ ExpC5 - TES antigo, para o caso de alteracao de TES        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RecalImp( nItem  	, nTipOper  , cItRecal  , xConteudo	,;
					  cTesOri	, nVlrItDesc, lPrimItem	, lAtuBasImp,;
					  lAltTotal	, lSomaAll)
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ nItem 	=> Item do array aColsDet que deve ser atualizado                               ³
//³ nTipOper	=> Tipo de operacao que esta sendo realizada:                               ³
//³              1 - Troca de Cliente/Loja ou Recalculo total dos impostos                  ³
//³              2 - Alteracao do TES ou qualquer campo que necessite recalculo dos impostos³
//³              3 - Inclusao de um novo item na venda                                      ³
//³              4 - Exclusao de um Item                                                    ³
//³              5 - Desmarca a delecao de Item                                             ³
//³              6 - Desconto Total na Venda                                                ³
//|				 7 -                                                                        |
//³ cItRecal => Item que deve ser informado na função MaFisAlt. Ex: "IT_TES"                ³
//³ xConteudo => Conteudo do campo alterado                                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

Static lControle := .F. // Variavel que controla quando devera ser zerada a variavel nAuxTotal
Static nUltItem  := 0   // Numero do ultimo item não deletado

Local nAuxTotal  := 0	// Variavel auxiliar que armazena o total da venda
Local nX         := 0  	// Variavel Contador
Local cIndImp    := ""	// Indice do imposto variavel
Local nLin       := 0  	// Posicao do campo de imposto variavel
Local aDadosImps := {}	// Array com informacoes sobre os impostos variaveis referentes a um TES
Local nValBase   := 0	// Base do Imposto Variavel
Local nValImp    := 0	// Valor do Imposto Variavel
Local nPosProd	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosDtTes	 := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})				// Posicao do Codigo do TES
Local cMsg       := ""  // Mensagem com o total dos impostos discriminados e incluidos
Local lItemOk	 := .T.	// Identifica se o item pode ser calculado (nao esta excluido)
Local nPosVlUnit := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]			// Posicao do Valor unitario do item
Local nPosQuant	 := aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_QUANT"})][2]			// Posicao da Quantidade
Local nAuxValor  := 0.00
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]		// Posicao do valor de desconto
Local nPosDesPro	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO"})				// Posicao do Desconto Proporcional
Local lItemDel		:= .F.                                                                          // Verifica se o item anterior foi deletado
Local nCont   		:= 0                                                                            // Contador de FOR
Local nTotDesc      := 0 		                                                                    // Total de desconto
Local cMvDescSai	:= SuperGetMV("MV_DESCSAI",,"1")												// Desconto tratamento localizacoes
Local lCalcIVA      := .F.																			// Verifica se e' calculo de IVA
Local nQtdImps      := 1                                                                            // Quantidade de impostos configurados
Local nCount        := 0 																			// Contador de For
Local cA1Tipo       := ""                                                                           // Tipo do cliente
Local lRet			:= .T.
Local cTipoFact  	:= If(cPaisLoc == "ARG", LjxDSerArg(), Nil)										// Verifica qual a serie da fatura quando pais Argentina (para fazer tratamentos diferenciados por causa da impressao da fatura ou cupom)
/*Release 11.5 - Controle de Formularios
  Paises: Chile / Colombia - F1CHI       */
Local lCFolLocR5	:= SuperGetMv("MV_CTRLFOL",,.F.) .AND. cPaisLoc$"CHI|COL" .AND. !lFiscal
Local cSigEspFo		:= ""																				//Especie (SIGLA) do controle de formulario informado pelo usuario

Default cItRecal	:= "IT_TES"
Default xConteudo	:= If(nItem <= Len(aColsDet),aColsDet[nItem][nPosDtTes],"")
Default cTesOri		:= ""	// Tes antigo, para o recalculo de impostos quando houver troca de TES
Default nVlrItDesc	:= 0
Default lPrimItem	:= .F.
Default lAtuBasImp	:= .F.
Default lAltTotal	:= .T.	//Define se altera o valor de Lj7T_Total, quando utilizado o desconto (nTipoOper = 6)
Default lSomaAll 	:= .F.  //Define se deve somar todos os itens de referencia da MatxFis

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Caso o array aColsDet esteja vazio ou o campo do codigo do produto esteja em branco nao é necessario³
//³realizar o calculo dos impostos variaveis...                                                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (nItem > Len(aColsDet) .OR. Empty(aCols[nItem][nPosProd]))
	lRet := .F.
EndIf

If lRet

	SA1->(DbSetOrder(1))     //Verifica o tipo do cliente
	If SA1->(DbSeek( xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA ))
		Do Case
			Case SA1->A1_TIPO = "X"
				cA1Tipo := "E"   //Isento
			Case SA1->A1_TIPO = "F" .OR. Empty( SA1->A1_TIPO )
				cA1Tipo := "C"   //Consumidor Final
			Case SA1->A1_TIPO = "S"
				cA1Tipo := "A"   //Nao responsavel
			Case SA1->A1_TIPO = "Z"
				cA1Tipo := "I"   //Responsavel Inscrito
			OtherWise
				cA1Tipo := SA1->A1_TIPO
		EndCase
	EndIf

	If nTipOper == 1

		If nItem == 1 .OR. lPrimItem
			aTotImpsV := {}
			nAuxTotal := 0
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se existem itens deletados e faz o acerto do valor da variavel nAuxTotal ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		lItemOk	:= !MaFisRet( nItem, "IT_DELETED" )
	 	If lItemOk .Or. lSomaAll
		    For nCont := 1 to Len(aCols)
		    	lItemDel:= MaFisRet(nCont, "IT_DELETED" )
		    	If !lItemDel
		    		nAuxTotal += MaFisRet(nCont, "IT_TOTAL" )
		    		nTotDesc  += MaFisRet(nCont, "IT_DESCONTO" )
		    	EndIf
		    Next
		EndIf

		// atualizar corretamente os itens sem o desconto total gravacao do campos L1_BASIMP1 e L2_BASIMP1
		If lAtuBasImp
			aDadosImps := TesImpInf(aColsDet[nItem][nPosDtTes])
			For nX := 1 To Len(aDadosImps)
				cIndImp := Substr(aDadosImps[nX][2],10,1)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o array de detalhes...³
				//³Base do Imposto...             ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
				nLin     := aPosCpoDet[ aScan(aPosCpoDet,{|x| Trim(x[1]) == "LR_BASIMP"+cIndImp}) ][02]
				aColsDet[nItem][nLin] := nValBase

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Valor Imposto..³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
				nLin := aPosCpoDet[ aScan(aPosCpoDet,{|x| Trim(x[1]) == "LR_VALIMP"+cIndImp}) ][02]
				aColsDet[nItem][nLin] := nValImp
			Next nX
		EndIf

		//Caso o parametro MV_DESCSAI estiver como 2 o SubTotal ja contempla o desconto
    	If cMvDescSai == "2"
    		If cPaisLoc <> "BRA"
				Lj7T_Subtotal( 2, nAuxTotal )
				Lj7T_Total( 2, Lj7T_Subtotal(2))
			Else
				Lj7T_Subtotal( 2, nAuxTotal )
				Lj7T_Total( 2, Lj7T_Subtotal(2) - Lj7T_DescV(2) )
			EndIf
		Else
			If cPaisLoc == "ARG"
				Lj7T_Subtotal( 2, nAuxTotal )
				Lj7T_Total( 2, Lj7T_Subtotal(2))
			Else
				Lj7T_Subtotal( 2, nAuxTotal - nTotDesc )
				Lj7T_Total( 2, Lj7T_Subtotal(2))
			EndIf
			Lj7ZeraPgtos()
		EndIf

		aDesconto := { 0, 0, 0 }

		If lItemOk
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Acerta array com o total dos Impostos Variaveis...³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7TotImpsV(nItem,nTipOper)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Release 11.5 - Controle de Formularios                        ³
			//³Se a especie do formulario escolhido pelo usuário no inicio   ³
			//³ da venda for 1-Factura, o valor do imposto sera discriminado.³
			//³Paises:Chile/Colombia - F1CHI						         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lCFolLocR5 .AND. LjGRecFo() > 0
				LjxDadosFo(LjGRecFo(),NIL,@cSigEspFo)
				If Rtrim(cSigEspFo) == "FCT"
					cMsg := STR0083+TransForm(A410Arred(Lj7T_ImpsV("1",2),"L1_VALIMP1",nMoedaCor),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))//"Total Impostos Discriminados"
		   		EndIf
			Else
		    	cMsg := STR0082+TransForm(Lj7T_ImpsV("3",2),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))+Space(10)+; //"Total Impostos Incluidos "
		            STR0083+TransForm(A410Arred(Lj7T_ImpsV("1",2),"L1_VALIMP1"),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))	           //"Total Impostos Discriminados"
			EndIf

			If aDadosJur[1] > 0
				If cPaisLoc == "CHI"
					/*Release 11.5 - Localizacao Chile -F1CHI
					Exibir casas decimais no % de Acrescimo*/
					cMsg := cMsg+Space(10)+STR0087+TransForm(aDadosJur[07],PesqPict("SL1","L1_JUROS"))+; //"Acrescimo % "
				        Space(10)+STR0088+TransForm(aDadosJur[01],PesqPict("SL1","L1_VLRTOT",,nMoedaCor))//"Acrescimo $ "
				Else
					cMsg := cMsg+Space(10)+STR0087+TransForm(aDadosJur[07],PesqPict("SL1","L1_JUROS",,nMoedaCor))+; //"Acrescimo % "
				        Space(10)+STR0088+TransForm(aDadosJur[01],PesqPict("SL1","L1_VLRTOT",,nMoedaCor))        //"Acrescimo $ "
				Endif
			EndIf
			Lj7R_Rodape(cMsg)
		EndIf

	Else
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Acerta array com o total dos Impostos Variaveis... Nesse momento a funcao eh chamada para que os valores³
		//³antigos sejam subtraidos do array do total dos impostos variaveis...                                    ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nTipOper == 2 .OR. nTipOper == 6

			Lj7TotImpsV(nItem,nTipOper,cItRecal,cTesOri)
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³BOPS 111545/109909 - Envio do TES antigo (original) para ³
			//³a funcao LJ7TOTIMPSV, para recalculo correto dos impostos³
	        //³quando se tratar de troca de TES                         ³
	        //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	        If  nVlrItDesc > 0 .AND. nTipOper == 6
				If cPaisLoc == "ARG"
					MaFisAlt("IT_DESCONTO", nVlrItDesc, nItem)
				Else
		            //Valor do desconto no item que eh zerado anteriormente e eh necessario para o recalculo do imposto
					MaFisAlt(cItRecal,MaFisRet(nItem, "IT_VALMERC") - nVlrItDesc,nItem)
				EndIf
			EndIf

		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Retira o valor antigo do item do SubTotal e Total              ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nTipOper == 1 .OR. nTipOper == 2
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Atualizo variaveis da tela                                     ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			Lj7T_Subtotal( 2, LJ7T_Subtotal(2) - MaFisRet( nItem, "IT_TOTAL" ) )
			Lj7T_Total( 2, LJ7T_SubTotal(2) - Lj7T_DescV(2) )
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Realiza o recalculo dos impostos...³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nTipOper == 2 .OR. nTipOper == 6
			If cPaisLoc <> "ARG" .Or. cItRecal <> "IT_VALMERC"
				MaFisAlt(cItRecal,xConteudo,nItem)
			EndIf
		EndIf

		If nTipOper <> 4 .AND. nTipOper <> 5
			aDadosImps := TesImpInf(aColsDet[nItem][nPosDtTes])
			For nX := 1 To Len(aDadosImps)
				cIndImp := Substr(aDadosImps[nX][2],10,1)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o array de detalhes...³
				//³Base do Imposto...             ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
				nLin     := aPosCpoDet[ aScan(aPosCpoDet,{|x| Trim(x[1]) == "LR_BASIMP"+cIndImp}) ][02]
				aColsDet[nItem][nLin] := nValBase

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Valor Imposto..³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
				nLin := aPosCpoDet[ aScan(aPosCpoDet,{|x| Trim(x[1]) == "LR_VALIMP"+cIndImp}) ][02]
		   		aColsDet[nItem][nLin] := nValImp
			Next nX
		EndIf

		// Verifica existe somente calculo de IVA
		If Len(aTotImpsV) > 0
			For nCount := 1 to Len(aTotImpsV)
				If aTotImpsV[nCount][1]$"IVA" .AND. (nQtdImps == Len(aTotImpsV))
					lCalcIVA := .T.
					nQtdImps++
				Else
					lCalcIVA := .F.
				EndIf
			Next nCount
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Acerta array com o total dos Impostos Variaveis...³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7TotImpsV(nItem,nTipOper)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Soma o valor novo do item do SubTotal e Total                  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nTipOper <> 3 .AND. nTipOper <> 4 .AND. nTipOper <> 5
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Atualizo variaveis da tela                                     ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nTipOper <> 6
				Lj7T_Subtotal( 2, LJ7T_Subtotal(2) + MaFisRet( nItem, "IT_TOTAL" ) )
				Lj7T_Total( 2, LJ7T_SubTotal(2) - Lj7T_DescV(2) )
			ElseIf lCalcIVA .AND. Lj7T_DescV(2) > 0
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Alteracao para calculo de imposto localizacao. Se o parametro  ³
				//³ MV_DESCSAI for igual a 2 , pega o valor ja calculado da MATXFIS³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If !(cPaisLoc $ "ARG|MEX") .And. nTipOper == 6 .AND. cMvDescSai == "1"
					Lj7T_Total( 2, LJ7T_SubTotal(2) - Lj7T_DescV(2) )
				Else
				    // Se estiver dentro da multinegociação, não adicionar no valor total da venda
				    // para não aparecer o valor multiplicado por x linhas do simulado de cotas
					If cPaisLoc == "MEX" .AND. IsInCallStack( "LJ76TELNEG" )
					    Lj7T_Total( 2,  MaFisRet( nItem, "IT_TOTAL" ))
					Else
						//esta função eh chamada pela Lj7LocTrib e quando passado o desconto não precisa
						//somar os valores pois estes já foram calculados
						If lAltTotal
						    Lj7T_Total( 2,  MAX(Lj7T_Total(2),0) + MaFisRet( nItem, "IT_TOTAL" ))
					    EndIf
					EndIf
				EndIf
			Else
			    // Se estiver dentro da multinegociação, não adicionar no valor total da venda
			    // para não aparecer o valor multiplicado por x linhas do simulado de cotas
				If cPaisLoc == "MEX" .AND. IsInCallStack( "LJ76TELNEG" )
				    Lj7T_Total( 2,  MaFisRet( nItem, "IT_TOTAL" ))
				Else
					If lAltTotal
					    Lj7T_Total( 2,  MAX(Lj7T_Total(2),0) + MaFisRet( nItem, "IT_TOTAL" ))
				    EndIf
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Release 11.5 - Controle de Formularios                                 ³
		//³Se a especie do formulario escolhido pelo usuário no   				  ³
		//³inicio da venda for FCT-FACTURA,o valor do imposto sera discriminado.  ³
		//³Paises:Chile/Colombia - F1CHI										  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lCFolLocR5 .AND. LjGRecFo() > 0
			LjxDadosFo(LjGRecFo(),NIL,@cSigEspFo)
			If Rtrim(cSigEspFo) == "FCT"
				cMsg := STR0083+TransForm(A410Arred(Lj7T_ImpsV("1",2),"L1_VALIMP1",nMoedaCor),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))//"Total Impostos Discriminados"
	   		EndIf
		Else
	    	cMsg := STR0082+TransForm(Lj7T_ImpsV("3",2),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))+Space(10)+; //"Total Impostos Incluidos "
	            STR0083+TransForm(A410Arred(Lj7T_ImpsV("1",2),"L1_VALIMP1"),PesqPict("SLR","LR_VALIMP1",,nMoedaCor))		 		//"Total Impostos Discriminados"
		EndIf

		If aDadosJur[1] > 0
			cMsg := cMsg+Space(10)+STR0087+TransForm(aDadosJur[07],PesqPict("SL1","L1_JUROS",,nMoedaCor))+; 	//"Acrescimo % "
			        Space(10)+STR0088+TransForm(aDadosJur[01],PesqPict("SL1","L1_VLRTOT",,nMoedaCor)) 			//"Acrescimo $ "
		EndIf

		Lj7R_Rodape(cMsg)
	EndIf
EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7FillPgtºAutor  ³ Vendas Clientes    º Data ³  08/01/2004 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao que preenche o array aPgtos ao modificar a parcela  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpC1 - Nome da moeda selecionada                          º±±
±±º          ³ ExpN1 - Moeda da parcela                                   º±±
±±º          ³ ExpN2 - Numero da linha do objeto oPgtos que esta sendo    º±±
±±º          ³        alterada.                                           º±±
±±º          ³ ExpN3 - Valor da parcela                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7FillPgto(cNomeMoeda, nMoedaParc, nLinha, nValorParc)
Local nX
Local nPosObj		:= IIF(IsBlind(),1,IIf(lVisuSint .AND. Type("oPgtosAna")=="O", oPgtosAna:nAt , oPgtos:nAt ))

For nX := 1 To MoedFin()
   If(!(Empty(SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))))))
      If SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))) == cNomeMoeda
         If nLinha > 0
	        aPgtos[nPosObj][_MOEDA] := nX
	        aPgtos[nPosObj][2]      := nValorParc
	     EndIf
	     nMoedaParc  := nX
		 Exit
      EndIf
   Else
      Exit
   EndIf
Next nX

Return NIL

/*/
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7DtEmis  ³ Autor ³ Vendas Clientes       ³Data  ³12/01/04   ±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Validacao da data de emissao do cheque                      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe	 ³ ExpL1 := Lj7DtEmis(dDataEmis,dDataForm,cComboPag,oPgtos,    ³±±
±±³          ³                      aPgtos)                                ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpD1 := Data de Emissao     				               ³±±
±±³          ³ ExpD1 := Data              				                   ³±±
±±³          ³ ExpC1 := Combo de pagamento				                   ³±±
±±³          ³ ExpO1 := Tela de pagamentos				                   ³±±
±±³          ³ ExpA1 := Matriz contendo as datas e valores para pagamentos ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso		 ³ LOJA701      											   ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7DtEmis(	dDataEmis,	dDataForm,	cComboPag,	oPgtos,;
							aPgtos)

Local lRet 		:= .T.
Local lAutoExB	:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao

If dDataForm >= dDataEmis .AND. IIf(cPaisLoc == "ARG|PAR", .T., dDataBase <= dDataEmis)
   lRet := .T.
Else
	If cPaisLoc == "ARG|PAR"
		If !lAutoExB
			MsgStop(STR0170) // "A data de emissao nao pode ser maior que a data de vencimento!"
		Else
			ConOut(STR0170) // "A data de emissao nao pode ser maior que a data de vencimento!"
		EndIf
	Else
		If !lAutoExB
			MsgStop(STR0084 + CRLF +; //"A data de emissao nao pode ser menor do que a data do sistema "
					STR0085) //"nem maior do que o vencimento!"
		Else
			ConOut(STR0084 + CRLF +; //"A data de emissao nao pode ser menor do que a data do sistema "
					STR0085) //"nem maior do que o vencimento!"
		EndIf
	EndIf
	lRet := .F.
EndIf

Return( lRet )

/*/
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7ConvMoeda ³ Autor ³ Vendas Clientes       ³Data  ³12/01/04  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Retornar o valor da parcela convertido para a moeda           ³±±
±±³          ³ selecionada.                                                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe	 ³ Lj7ConvMoeda(ExpC1,ExpO1,ExpN1,ExpO2,ExpA1,ExpA2,ExpN2)       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpC1 := Moeda da parcela     				                 ³±±
±±³          ³ ExpO1 := Objeto referente ao combo da moeda da parcela        ³±±
±±³          ³ ExpN1 := Valor da parcela				                     ³±±
±±³          ³ ExpO2 := Objeto do get do valor da parcela                    ³±±
±±³          ³ ExpA1 := Matriz utilizada no combo da moeda da parcela        ³±±
±±³          ³ ExpA2 := Matriz com o valor da parcela em diversas moedas     ³±±
±±³          ³ ExpN2 := Moeda selecionada                                    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso		 ³ LOJA701  	     									         ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7ConvMoeda(cMoedaTit  , oComboMoeda, nValor     , oValor,;
                             aCbxMoeda  , aVal       , nMoedaSel            )
Local oDlgConv
Local oLbx
Local oOk  	  := LoadBitMap(GetResources(), "LBOK")
Local oNo	  := LoadBitMap(GetResources(), "LBNO")
Local aSizes  := {05,40,25}
Local aFields := {" ",STR0005,STR0078}   //"Valor"###"Moeda"
Local nI      := 0
Local nOpc    := 0
Local nValParc:= 0
Local lIgual  := .F.

If Empty(aVal)
	For nI := 1 To Len(aCbxMoeda)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Nao usar Round para nao causar diferencas de arredondamento                 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValParc := xMoeda(nValor,oComboMoeda:nAt,nI,dDataBase,MsDecimais(nI)+1)
		AAdd(aVal,{-1,nValParc,aCbxMoeda[nI],MsDecimais(nI),nValParc,SuperGetMV("MV_SIMB"+AllTrim(Str(nI)))})
	Next nI
Else
	If aVal[ ASCAN( aVal, { |x| TRIM(x[3]) == TRIM(cMoedaTit)})][5] == nValor
		lIgual := .T.
	EndIf

	For nI := 1 To Len(aCbxMoeda)
		If lIgual
			aVal[nI,1] := -1
			aVal[nI,2] := aVal[nI,5]
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Nao usar Round para nao causar diferencas de arredondamento                 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Else
			nValParc := xMoeda(nValor,oComboMoeda:nAt,nI,dDataBase,MsDecimais(nI)+1)
			aVal[nI,1] := -1
			aVal[nI,2] := nValParc
			aVal[nI,5] := nValParc
		EndIf
	Next nI
EndIf

DEFINE MSDIALOG oDlgConv FROM 12,65 TO 25,95 TITLE STR0086  ;  //"Selecao do Valor e da Moeda"
STYLE nOr( DS_MODALFRAME, WS_DLGFRAME ) OF oDlgVA

//                      LS  CE  CD  LI
oLBx := TWBrowse():New(010,004,110,060,,aFields,aSizes,oDlgConv,,,,,,,,,,,,.F.,,.T.,,.F.,,,)
oLBx:SetArray(aVal)
oLBx:bLDblClick	:= {|| Lj7MkBrw(@aVal,@oLbx)}
oLBx:bLine := {|| {If(aVal[oLBx:nAt,1]==-1,oNo,oOk),TransForm(aVal[oLBx:nAt,2],Tm(aVal[oLBx:nAt,2],16,aVal[oLBx:nAt,4])),aVal[oLBx:nAt,3]}}

DEFINE SBUTTON FROM 075,058 TYPE 1 ACTION (nOpc:=1,oDlgConv:End()) ENABLE OF oDlgConv
DEFINE SBUTTON FROM 075,088 TYPE 2 ACTION (nOpc:=2,oDlgConv:End()) ENABLE OF oDlgConv

ACTIVATE MSDIALOG oDlgConv

If nOpc == 1
	If ( nI := ASCAN( aVal, { |x| x[1] == 1 } ) ) > 0
	    nMoedaSel := nI
		nValor    := aVal[nI,2]
		oValor:Refresh()

		cMoedaTit  := aVal[nI,3]
		oComboMoeda:nAt := ASCAN( oComboMoeda:aItems, { |x| TRIM(x) == TRIM(cMoedaTit) } )
		oComboMoeda:Refresh()
	EndIf
EndIf

Return(Nil)

/*/
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7MkBrw     ³ Autor ³ Vendas Clientes       ³Data  ³29/01/03  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Controla a marca/desmarca realizada na selecao do valor da    ³±±
±±³          ³ parcela convertido.                                           ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe	 ³ Lj7MkBrw(ExpA1,ExpO1)                                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpA1 := Matriz com o valor da parcela em diversas moedas     ³±±
±±³          ³ ExpO1 := Objeto referente ao TWBrowse                         ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso		 ³ LOJA701      	     									     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7MkBrw(aVal, oLbx)

Local nPosCol := oLBx:ColPos
Local nValParc:= aVal[oLBx:nAt,1]

If nPosCol == 1
	aEval(aVal,{|x,y| x[1]:=If(y <> oLBx:nAt,-1,1)})
ElseIf aVal[oLBx:nAt,1] == 1
	oLBx:ColPos := 2
	MaFisEditCell(@nValParc,oLBx,PesqPict("SL4","L4_VALOR",16,oLBx:nAt),2,'Lj7VldGetMoeda()')
EndIf

oLBx:ColPos := 1
SysRefresh()
oLBx:Refresh()

Return(Nil)

/*/
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7VldGetMoed³ Autor ³ Vendas Clientes       ³Data  ³12/01/04  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Realiza a validacao do valor informado pelo usuario no        ³±±
±±³          ³ TWBrowse.                                                     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe	 ³ ExpL1 := Lj7VldGetMoeda()                                     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ ExpL1 := .T. para o dado valido e .F. para o dado invalido    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso		 ³ LOJA701      	     									     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Function Lj7VldGetMoeda()

Local lRet := .T.

If M->CELL <= 0
	lRet := .F.
Else
	lRet := .T.
EndIf

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7TotImpsVºAutor  ³ Vendas Clientes   º Data ³  12/01/2004 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao que recalcula os impostos variaveis(Localizacoes)   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1 - Item do array aColsDet que deve ser atualizado     º±±
±±º          ³ ExpN2 - Tipo de operacao que esta sendo realizada:         º±±
±±º          ³         1 - Troca de Cliente/Loja                          º±±
±±º          ³         2 - Alteracao do TES ou qualquer campo que necessi-º±±
±±º          ³             te recalculo dos impostos                      º±±
±±º          ³         3 - Inclusao de um novo item na venda              º±±
±±º          ³         4 - Exclusao de um Item                            º±±
±±º          ³         5 - Desmarca a delecao de Item                     º±±
±±º          ³ ExpC3 - Item que deve ser informado na função MaFisAlt.    º±±
±±º          ³         Ex: "IT_TES"                                       º±±
±±º          ³ ExpC4 - TES antigo, para o caso de recalculo de TES quando º±±
±±º          ³         alterado                                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7TotImpsV(nItem, nTipOper, cItRecal,cTesOri)
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ nTipOper	=> Tipo de operacao que esta sendo realizada:                               ³
//³              1 - Troca de Cliente/Loja                                                  ³
//³              2 - Alteracao do TES ou qualquer campo que necessite recalculo dos impostos³
//³              3 - Inclusao de um novo item na venda                                      ³
//³              4 - Exclusao de um Item                                                    ³
//³              5 - Desmarca a delecao de Item                                             ³
//³              6 - Desconto no total da Venda                                             ³
//³ nItem 	=> Item do array aColsDet que deve ser atualizado                               ³
//³ cItRecal => Item que deve ser informado na função MaFisRet. Ex: "IT_TES"                ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

Static nPasso := 1

Local nX    := 0																		// Contador de For
Local nLin  := 0																		// Linha
Local nPosDtTes := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})				// Posicao do Codigo do TES
Local aAreaSFB  := {}																	// Area do SFB
Local nCont     := 0                                                                    // Contador de For
Local nPosImp	:= 0																	// Posicao do Imposto Totalizado no array aTotImpsV
Local cTes		:= ""

Default cItRecal 	:= "IT_TES"															// TES
Default cTesOri  	:= ""																	// TES antigo, para recalculo de impostos quanto for troca de TES (nTipOper = 2)

cTes :=	aColsDet[nItem][nPosDtTes]

If nTipOper == 6
	aDadosImps := TesImpInf(MaFisRet(nItem,"IT_TES"))
	For nX := 1 To Len(aDadosImps)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Indice do Imposto (Ex: ValImp"1", ValImp"2"...)³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		cIndImp := Substr(aDadosImps[nX][2],10,1)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Base do Imposto...                              ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Valor Imposto..³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
		If aDadosImps[nX][3] == "1"
           nVlrImpDisc += nValImp
        EndIf
		If nValBase > 0 .AND. nValImp > 0
			nLin := aScan(aTotImpsV,{|x| Trim(x[1])==AllTrim(aDadosImps[nX][1])})
			If nLin == 0
				aAreaSFB := SFB->(GetArea())
				SFB->(DbSetOrder(1))
				SFB->(DbSeek(xFilial("SFB")+aDadosImps[nX][1]))
				AAdd(aTotImpsV,{aDadosImps[nX][1],SFB->FB_DESCR,nValBase,nValImp,aDadosImps[nX][03]})
				SFB->(RestArea(aAreaSFB))
				If nPasso > 1
					nPasso--
				EndIf
			Else
				If nPasso == 1
			    	For nCont := 1 To Len(aDadosImps)
			    		cIndImp := Substr(aDadosImps[nCont][2],10,1)
			    		nValBase:= MaFisRet(nItem,"IT_BASEIV"+cIndImp)
			    		nValImp := MaFisRet(nItem,"IT_VALIV"+cIndImp)
			    		nPosImp := aScan(aTotImpsV,{|x| Alltrim(x[1]) == AllTrim(aDadosImps[nCont][1])})
			    		If nPosImp <> 0

			    		    If Len(aDadosImps) == 1  .OR. (Len(aDadosImps) > 1 .AND. Len(aCols)> 1 )
								aTotImpsV[nPosImp][03] -= nValBase
								aTotImpsV[nPosImp][04] -= nValImp
								If aTotImpsV[nPosImp][03] < 0
								   aTotImpsV[nPosImp][03]  := 0
								EndIf
								If aTotImpsV[nPosImp][04] < 0
								   aTotImpsV[nPosImp][04]  := 0
								EndIf
							Else
								aTotImpsV[nPosImp][03] := 0
								aTotImpsV[nPosImp][04] := 0
							EndIf

						Endif
					Next nCont
				  	nPasso++
				  	Exit
				Else
				   	For nCont := 1 To Len(aDadosImps)
			    		cIndImp := Substr(aDadosImps[nCont][2],10,1)
			    		nValBase:= MaFisRet(nItem,"IT_BASEIV"+cIndImp)
			    		nValImp := MaFisRet(nItem,"IT_VALIV"+cIndImp)
			    		nPosImp := aScan(aTotImpsV,{|x| Alltrim(x[1]) == AllTrim(aDadosImps[nCont][1])})
			    		If nPosImp <> 0
			    			aTotImpsV[nPosImp][03] += nValBase
							aTotImpsV[nPosImp][04] += nValImp
						Endif
				  	Next nCont
					nPasso--
					Exit
				EndIf
			EndIf
		EndIf
	Next nX
ElseIf nTipOper == 1 .OR. nTipOper == 3 .OR. nTipOper == 5
	If nTipOper == 1 .AND. nItem == 1
		aTotImpsV := {}
	EndIf

	aDadosImps := TesImpInf(cTes)
	For nX := 1 To Len(aDadosImps)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Indice do Imposto (Ex: ValImp"1", ValImp"2"...)³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		cIndImp := Substr(aDadosImps[nX][2],10,1)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Base do Imposto...                              ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Valor Imposto..³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
		If aDadosImps[nX][3] == "1"
           nVlrImpDisc += nValImp
        EndIf

		If nValBase > 0 .AND. nValImp > 0
			nLin := aScan(aTotImpsV,{|x| Trim(x[1])==AllTrim(aDadosImps[nX][1])})
			If nLin == 0
				aAreaSFB := SFB->(GetArea())
				DbSetOrder(1)
				SFB->(DbSeek(xFilial("SFB")+aDadosImps[nX][1]))
				AAdd(aTotImpsV,{aDadosImps[nX][1],SFB->FB_DESCR,nValBase,nValImp,aDadosImps[nX][03]})
				SFB->(RestArea(aAreaSFB))
			Else
				aTotImpsV[nLin][03] += nValBase
				aTotImpsV[nLin][04] += nValImp
			EndIf
		EndIf
	Next nX
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Alteracao de TES³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
ElseIf nTipOper == 2
    If AllTrim(cTesOri) <> ""
        If AllTrim(cTesOri) <> cTes
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³BOPS 111545/109909 - Recalcula e subtrai os³
			//³valores referentes ao TES antigo           ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
            MaFisAlt("IT_TES", cTesOri, nItem)
	        aDadosImps := TesImpInf(MaFisRet(nItem,"IT_TES"))
	        For nX := 1 To Len(aDadosImps)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Indice do Imposto (Ex: ValImp"1", ValImp"2"...)³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		        cIndImp := Substr(aDadosImps[nX][2],10,1)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Base do Imposto...                              ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		        nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Valor Imposto..³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		        nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
		        If aDadosImps[nX][3] == "1"
                    nVlrImpDisc -= nValImp
                EndIf
		        If nValBase > 0 .AND. nValImp > 0
			        nLin := aScan(aTotImpsV,{|x| Trim(x[1])==AllTrim(aDadosImps[nX][1])})
			        If nLin <> 0
				        aTotImpsV[nLin][03] -= nValBase
				        aTotImpsV[nLin][04] -= nValImp
				    EndIf
                EndIf
            Next nX
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³BOPS 111545/109909 - Recalcula e adiciona os³
			//³valores referentes ao novo TES              ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
            MaFisAlt("IT_TES", cTes, nItem)
	        aDadosImps := TesImpInf(MaFisRet(nItem,"IT_TES"))
	        For nX := 1 To Len(aDadosImps)
		        // Indice do Imposto (Ex: ValImp"1", ValImp"2"...)
		        cIndImp := Substr(aDadosImps[nX][2],10,1)
		        //Base do Imposto...
		        nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
		        //Valor Imposto..
		        nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
		        If aDadosImps[nX][3] == "1"
                    nVlrImpDisc += nValImp
                EndIf
		        If nValBase > 0 .AND. nValImp > 0
			        nLin := aScan(aTotImpsV,{|x| Trim(x[1])==AllTrim(aDadosImps[nX][1])})
			        If nLin == 0
				        aAreaSFB := SFB->(GetArea())
				        DbSetOrder(1)
				        SFB->(DbSeek(xFilial("SFB")+aDadosImps[nX][1]))
				        AAdd(aTotImpsV,{aDadosImps[nX][1],SFB->FB_DESCR,nValBase,nValImp,aDadosImps[nX][03]})
				        SFB->(RestArea(aAreaSFB))
				    Else
				        aTotImpsV[nLin][03] += nValBase
				        aTotImpsV[nLin][04] += nValImp
                    EndIf
                EndIf
            Next nX
        EndIf
    EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Finalizacao de Venda³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
ElseIf nTipOper == 7
	aDadosImps := TesImpInf(cTes)
	For nX := 1 To Len(aDadosImps)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Indice do Imposto (Ex: ValImp"1", ValImp"2"...)³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		cIndImp := Substr(aDadosImps[nX][2],10,1)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Base do Imposto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Valor Imposto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
		If aDadosImps[nX][3] == "1"
           nVlrImpDisc += nValImp
        EndIf

		If nValBase > 0 .AND. nValImp > 0
			nLin := aScan(aTotImpsV,{|x| Trim(x[1])==AllTrim(aDadosImps[nX][1])})
			If nLin == 0
				aAreaSFB := SFB->(GetArea())
				DbSelectArea("SFB")
				DbSetOrder(1)
				If DbSeek(xFilial("SFB")+aDadosImps[nX][1])
					AAdd(aTotImpsV,{aDadosImps[nX][1],SFB->FB_DESCR,nValBase,nValImp,aDadosImps[nX][03]})
				EndIf
				RestArea(aAreaSFB)
			Else
				aTotImpsV[nLin][03] += nValBase
				aTotImpsV[nLin][04] += nValImp
			EndIf
		EndIf
	Next nX
Else
	aDadosImps := TesImpInf(cTes)
	For nX := 1 To Len(aDadosImps)
		// Indice do Imposto (Ex: ValImp"1", ValImp"2"...)
		cIndImp := Substr(aDadosImps[nX][2],10,1)

		//Base do Imposto...
		nValBase := MaFisRet(nItem,"IT_BASEIV"+cIndImp)

		//Valor Imposto..
		nValImp  := MaFisRet(nItem,"IT_VALIV"+cIndImp)
		If aDadosImps[nX][3] == "1"
           nVlrImpDisc += nValImp
        EndIf

		If nValBase > 0 .AND. nValImp > 0
			nLin := aScan(aTotImpsV,{|x| Trim(x[1])==AllTrim(aDadosImps[nX][1])})
			If nLin > 0
				aTotImpsV[nLin][03] -= nValBase
				aTotImpsV[nLin][04] -= nValImp
			EndIf
		EndIf
	Next nX
EndIf

Return Nil

/*/ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³Lj7MontPgt³Autora ³ Vendas Clientes       ³ Data ³ 18/10/04 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Prepara a array sintetizada para exibição                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ LOJA701                                                    ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß/*/
Function Lj7MontPgt(aParc, nMoedaAux, lJob , lTefPend)
Local nFor 	 		:= 0
Local cCond  		:= ""
Local nValor 		:= 0
Local nParc	 		:= 0
Local cFormaId 		:= Space(01)
Local cChequeId		:= IIf(SL4->(ColumnPos("L4_CHEQID"))>0,Space(TamSx3("L4_CHEQID")[1]),Space(1))
Local nPos	 		:= 0
Local aParcSint		:= {}
Local aSequencia	:= {}
Local cSimbMoeda	:= SuperGetMV("MV_SIMB1")				// Simbolo da moeda da venda (parcela em dinheiro)
Local lVisualSint   := .F.									// Controla se esta habilitada a visualizacao sintetica das parcelas
Local nMoedaAtu     := 1									// Moeda corrente da venda
Local lVendaAss     := IsInCallStack("LJ7VENDA")			// Controla se foi chamado da Venda Assistida
Local aAdmTEF		:= {}
Local aRetLJORDFP	:= {}

Default aParc	  	:= {}									// Array para com as parcelas a sintetizar
Default nMoedaAux	:= 1									// Moeda corrente
Default lJob		:= .F.									// Verifica se esta' sendo execuitado via JOB
Default lTefPend	:= .F.

If !lJob .AND. Type("nMoedaCor") == "N"
	nMoedaAux := nMoedaCor
Endif

If SL4->(ColumnPos("L4_FORMAID")) > 0
   lVisualSint   := .T.
EndIf

If lVisualSint
   cFormaId  := Space(TamSX3("L4_FORMAID")[1])
EndIf

If lVendaAss
   cSimbMoeda	:= SuperGetMV("MV_SIMB"+ALLTRIM(STR(nMoedaAux)))
   nMoedaAtu    := nMoedaAux
EndIf

//Verifica se a aPgtos ou a aDados está zerada
If Len(aParc) == 1 .AND. aParc[1][2] == 0
	aParcSint := { {Space(02),0,TransForm(0,PesqPict("SL4","L4_VALOR",,nMoedaAtu)),Space(TamSX3("L4_FORMAID")[1]),Ctod(Space(8)),{},cChequeId} }

//Efetua o tratamento para a sintetização das informações
ElseIf Len(aParc) > 0
	aParcSint := {}						//Limpa o array para soma dos valores sintetizados

	For nFor:= 1 To Len(aParc)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Gera array sintetico de acordo com a quantidade de cartoes³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		cCond  		:= AllTrim(aParc[nFor][3])

		If nModulo == 23	// No Front a posicao do ID e a 12
			cFormaId 	:= aParc[nFor][12]
		Else
			cFormaId 	:= If(Len(aParc[nFor]) >= 8 .And. !Empty(aParc[nFor][8]) , aParc[nFor][8] , "")
		EndIf

		If cPaisLoc == "ARG" .AND. cCond $ "CH" .AND. (SL4->(ColumnPos("L4_CHEQID")) > 0)
			cChequeId	:= aParc[nFor][9]
			nPos		:= Ascan(aParcSint, { |x| ( AllTrim(x[1]) == cCond .AND. AllTrim(x[7]) == AllTrim(cChequeId) ) })
		Else
			cChequeId	:= Space(1)
			nPos		:= Ascan(aParcSint, { |x| ( AllTrim(x[1]) == cCond .AND. AllTrim(x[4]) == AllTrim(cFormaId) ) })
		EndIf

		If nPos > 0
			aParcSint[nPos][2] := aParcSint[nPos][2] + 1				//Parcela
			aParcSint[nPos][3] := aParcSint[nPos][3] + aParc[nFor][2]	//Valor
		Else
			nParc	:= 1
			nValor	:= aParc[nFor][2]
			If lTefPend .AND. cCond $ _FORMATEF .OR. ; // Quando tem TEF Pendente nao deve apagar a adm
			   (SLQ->(FieldPos("LQ_CODMNEG")) > 0 .And. Type("M->LQ_CODMNEG") <> "U" .And. !Empty(M->LQ_CODMNEG)) // Como nao permite alterar as formas grava na multinegociacao.
				aAdmTEF := aParc[nFor][4]
			Else
				aAdmTEF := {}
			EndIf
			Aadd( aParcSint , { cCond , nParc , nValor , cFormaId, aParc[nFor][1], aAdmTEF, cChequeId  } )
		EndIf

    	Aadd( aSequencia , {nFor , cCond , nValor, cFormaId} )
	Next nFor

	//Atualizando a sequencia para a array apgtos
	If lVendaAss
		For nFor := 1 To Len(aPgtos)
			nPos := Ascan(aSequencia,{|x| x[1] == nFor})
			If nPos > 0
				aPgtos[nFor][8] := aSequencia[nPos][4]
			EndIf
		Next nFor
	Else
		For nFor := 1 To Len(aParc)
			nPos := Ascan(aSequencia,{|x| x[1] == nFor})
			If nPos > 0
				aParc[nFor][8] := aSequencia[nPos][4]
			EndIf
		Next nFor
	EndIf

	/*Formata na Picture do L4_VALOR*/
	For nFor := 1 to Len(aParcSint)
		aParcSint[nFor][3] := TransForm(aParcSint[nFor][3],PesqPict("SL4","L4_VALOR",,nMoedaAtu))
	Next nFor
EndIf

If ExistBlock("LJORDFP") //Ponto de Entrada que permite modificar a ordenacao do array de pagamento na tela do venda assistida.
    aRetLJORDFP := ExecBlock( "LJORDFP", .F., .F., { aParcSint } )
    //Faz verificacao para validar se retornou o mesmo tamanho do array enviado como parametro
    If Len(aRetLJORDFP) == Len(aParcSint)
        aParcSint := aRetLJORDFP
    Else
        MsgStop(STR0202 + "LJORDFP") //"Foi retornada uma estrutura inválida do array de pagamento durante sua ordenação. Verifique o Ponto de Entrada: " ### "LJORDFP"
    EndIf
ElseIf SuperGetMV("MV_LJORDFP",,.T.)
	aSort( aParcSint,,, {|x,y| Dtos(x[5])+x[1]+x[4] < Dtos(y[5])+y[1]+y[4] } ) //Data + Cond + Seq.
EndIf

/* A Forma $ sempre sera a primeira!!!  */
If (nPos := Ascan(aParcSint, {|x| x[1] == cSimbMoeda})) > 1
	aAdd(aParcSint,{})
	aIns(aParcSint,1)
	nPos++
	aParcSint[1] := aParcSint[nPos]
	aDel(aParcSint, nPos)
	aSize(aParcSint,Len(aParcSint)-1)
EndIf

Return aParcSint

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7AltPgSiºAutor  ³ Vendas Clientes    º Data ³  10/18/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Prepara a array apgtos para ser tratada a partir de uma novaº±±
±±º          ³tela, pois na principal será exibida a Sintetizada.         º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7AltPgSi( nLinha, nOpc ,lTefPendCS , aTefBKPCS)
Local lContinua	  := .T.					//Laço para o controle da abertura de tela
Local lConfirma   := .F.					//Indica se o operador confirmou a alteração das parcelas
Local lLj7012	  := ExistBlock("LJ7012")	//Validação para o ponto de entrada
Local nPos		  := 0						//Identifica a posição da informação na Array
Local oDlgPgtoSin							//Objeto para tratamento da janela
Local lVerEmpres  := Lj950Acres(SM0->M0_CGC) 	// Verifica as filiais da trabalharam com acrescimento separado
Local lFTVD7012	  := ExistBlock("FTVD7012")	//Validação para o ponto de entrada
Local lAltaPgtos   := SuperGetMV( "MV_LJALTAP",,.F.) //Permite alteração do aPgtos apos escolha da condição de pagameto na finalização da venda
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

DEFAULT aTefBKPCS := {}

Private oPgtosAna								//Cópia do Objeto oPgtos que será aberto em outra tela

Default nLinha 	  	:= 0
Default lTefPendCS:=.F.

While lContinua

	lConfirma := .F.

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria interface com o usuario                                          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DEFINE MSDIALOG oDlgPgtoSin TITLE STR0109 FROM 0,0 TO 20,50 OF oDlgVA //"Detalhes da Forma de Pagamento"

	DEFINE SBUTTON FROM 136,170	TYPE 1 ACTION (lConfirma := .T. , oDlgPgtoSin:End()) ENABLE

	oPgtosAna	:= TCBrowse()	:New( 5, 5, 190, 125,;
								 Nil, Nil, Nil, Nil, Nil, Nil, Nil, Nil, Nil,,,,,,,,, .T. )
	If nOpc <> 2
		If nOpc == 4 .AND. !Empty(SL1->L1_ORCRES) .AND. !Empty(SL1->L1_FILRES)
			oPgtosAna:bLDblClick	    := { || Aviso( STR0001, STR0002,{STR0003} ) } //'Atenção'###'Não é permitida a alteração das formas de pagamento de um orçamento gerado com reserva.'###'Ok'
		ElseIf SLQ->(FieldPos("LQ_CODMNEG")) > 0 .And. !Empty(M->LQ_CODMNEG)
			oPgtosAna:bLDblClick	    := { || Aviso( STR0001, STR0200,{STR0003} ) } //"Atenção'###"Não é permitida a alteração das formas de pagamento quando utilizado Multi Negociação".###'Ok'
		ElseIf !lAltaPgtos
            oPgtosAna:bLDblClick	    := { || Aviso( STR0001, STR0208 + CRLF + STR0209 ,{STR0003} ) } //"Atenção'
            //#"Não é permitido alterar as opções de pagamento quando uma 'Condição de Pgto' estiver selecionada.
            //#"Para redefinir as opções de pagamento, clique no botão "Zerar Pagamentos" e selecione as opções desejadas."
		Else
			oPgtosAna:bLDblClick	    := {|| Lj7AltPgt(oPgtosAna:nAt, Nil			, Nil, lTefPendCS,;
														 NIL		  , aTefBKPCS)	}
		EndIf
	EndIf

	oPgtosAna:SetArray( aPgtos )

	If cPaisLoc == "ARG" .AND. aPgtosSint[oPgtosSint:nAt][1] $ "CH" .AND. (SL4->(FieldPos("L4_CHEQID")) > 0)
		nPos := Ascan(aPgtos, { |x| ( AllTrim(x[3]) == AllTrim(aPgtosSint[oPgtosSint:nAt][1]) .AND. AllTrim(x[9]) == AllTrim(aPgtosSint[oPgtosSint:nAt][7]) ) })
	Else
		nPos := Ascan(aPgtos, { |x| ( AllTrim(x[3]) == AllTrim(aPgtosSint[oPgtosSint:nAt][1]) .AND. AllTrim(x[8]) == AllTrim(aPgtosSint[oPgtosSint:nAt][4]) ) })
	EndIf

	If nPos>0
		oPgtosAna:nAt 	:= nPos
	EndIf
	oPgtosAna:Refresh()

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³A validacao da 5 coluna abaixo foi efetuada devido a um       ³
	//³procedimento utilizado para atualizacao do ListBox, onde a    ³
	//³sintaxe que insere  uma nova coluna sao reprocessadas novamente
	//³sob efeito do comando Refresh(), sendo assim, o mesmo nao deve³
	//³ser desenvolvido dinamicamente.                               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (lLj7012 .AND. !lFtvdVer12) .OR. (lFTVD7012 .AND. lFtvdVer12)
		If !lFtvdVer12
			aColCustom := ExecBlock( "LJ7012",.F.,.F. )
		ElseIf lFTVD7012
			aColCustom := ExecBlock( "FTVD7012",.F.,.F. )
		EndIf

		If aColCustom[2] == 1
			ADD COLUMN TO oPgtosAna HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtosAna:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtosAna HEADER STR0004 				OEM DATA { || aPgtos[oPgtosAna:nAt,1] } 										ALIGN LEFT  SIZE 40 PIXEL //"Data"

		If aColCustom[2] == 2
			ADD COLUMN TO oPgtosAna HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtosAna:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtosAna HEADER STR0145 				OEM DATA { || Transform(aPgtos[oPgtosAna:nAt,2],PesqPict("SL1","L1_VLRTOT")) } 	ALIGN RIGHT SIZE 50 PIXEL //"Valor Pago"

		If aColCustom[2] == 3
			ADD COLUMN TO oPgtosAna HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtosAna:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		ADD COLUMN TO oPgtosAna HEADER STR0006 				OEM DATA { || aPgtos[oPgtosAna:nAt,3] } 										ALIGN LEFT  SIZE 20 PIXEL //"Forma Pgto"

		If aColCustom[2] == 4
			ADD COLUMN TO oPgtosAna HEADER aColCustom[1] 	OEM DATA { || aPgtos[oPgtosAna:nAt,5] } 										ALIGN LEFT  SIZE 40 PIXEL
		EndIf

		//Só inserir a coluna ID Cartão quando o cliente trabalhar com múltiplas transações TEF
		If cPaisLoc == "BRA"
			If lUsaTef .AND. SuperGetMV("MV_TEFMULT") .AND. lVisuSint
				ADD COLUMN TO oPgtosAna HEADER STR0104 			OEM DATA { || aPgtos[oPgtosAna:nAt,8] } 											ALIGN LEFT  SIZE 20 PIXEL //"ID Cartão"
			EndIf
		Else
			If SuperGetMV("MV_TEFMULT") .AND. lVisuSint
				ADD COLUMN TO oPgtosAna HEADER STR0104 			OEM DATA { || aPgtos[oPgtosAna:nAt,8] } 											ALIGN LEFT  SIZE 20 PIXEL //"ID Cartão"
			EndIf
		EndIf
	Else

		ADD COLUMN TO oPgtosAna HEADER STR0004 				OEM DATA { || aPgtos[oPgtosAna:nAt,1] } 										ALIGN LEFT  SIZE 40 PIXEL //"Data"
		ADD COLUMN TO oPgtosAna HEADER STR0145 				OEM DATA { || Transform(aPgtos[oPgtosAna:nAt,2],PesqPict("SL1","L1_VLRTOT")) } 	ALIGN RIGHT SIZE 50 PIXEL //"Valor Pago"
		ADD COLUMN TO oPgtosAna HEADER STR0006 				OEM DATA { || aPgtos[oPgtosAna:nAt,3] } 										ALIGN LEFT  SIZE 20 PIXEL //"Forma Pgto"

		If cPaisLoc <> "BRA"
		   ADD COLUMN TO oPgtosAna HEADER STR0078 			OEM DATA { || aPgtos[oPgtosAna:nAt,_MOEDA] } 									ALIGN LEFT  SIZE 20 PIXEL //"Moeda"
		   ADD COLUMN TO oPgtosAna HEADER STR0079 			OEM DATA { || aPgtos[oPgtosAna:nAt,_EMISSAO] } 									ALIGN LEFT  SIZE 40 PIXEL //"Emissao"
		EndIf

		//Só inserir a coluna ID Cartão quando o cliente trabalhar com múltiplas transações TEF
		If cPaisLoc == "BRA"
			If lUsaTef .AND. SuperGetMV("MV_TEFMULT") .AND. lVisuSint
				ADD COLUMN TO oPgtosAna HEADER STR0104 			OEM DATA { || aPgtos[oPgtosAna:nAt,8] } 										ALIGN LEFT  SIZE 20 PIXEL //"ID Cartão"
			EndIf
        Else
			If SuperGetMV("MV_TEFMULT") .AND. lVisuSint
				ADD COLUMN TO oPgtosAna HEADER STR0104 			OEM DATA { || aPgtos[oPgtosAna:nAt,8] } 										ALIGN LEFT  SIZE 20 PIXEL //"ID Cartão"
			EndIf
        EndIf
        If cPaisLoc == "ARG" .AND. (SL4->(FieldPos("L4_CHEQID")) > 0) .AND. (aPgtos[oPgtosAna:nAt,3] $ "CH" )
        	ADD COLUMN TO oPgtosAna HEADER STR0171 			OEM DATA { || aPgtos[oPgtosAna:nAt,9] } 										ALIGN LEFT  SIZE 20 PIXEL //"ID Cheque"
        EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se trabalha com conceito de acrescimo separado,³
	//³Exibir o valor do acrescimo separado da parcela³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    If lVerEmpres .OR. (SuperGetMV("MV_LJICMJR",,.F.) .AND. cPaisLoc == "BRA")
		//"Acrs.Fin"
		oPgtosAna:AddColumn(TCColumn():New(STR0193,{|| If(Len(aPgtos)>=oPgtosAna:nAt,Transform(aPgtos[oPgtosAna:nAt,9],PesqPict("SL1","L1_VLRTOT",15)),'')},,,, "RIGHT", 60, .F., .F.,,,, .F., ) )  //"Acrs.Fin"
	Endif
	ACTIVATE MSDIALOG oDlgPgtoSin CENTERED

	If lConfirma
		oPgtos:SetArray(aPgtos)
		oPgtos:Refresh()

		aPgtosSint := Lj7MontPgt(aPgtos,.T.,NIL,lTefPendCS)
		oPgtosSint:SetArray( aPgtosSint )
		oPgtosSint:Refresh()

		lContinua := .F.
	EndIf
End
Return(Nil)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7WhenID ºAutora ³ Vendas Clientes    º Data ³  11/04/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se eh necessaria a digitacao do digito de controleº±±
±±º          ³ de cartoes                                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7WhenID(	nLinha	,	cForma,		cFormaID, 	oCart,;
							oIDCart )
Local lRet 		:= .F.
Local nPos 		:= Ascan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})
Local cFormVale	:= IIf(SuperGetMV("MV_LJVALEP",,.F.),_FORMATEF+";VP",_FORMATEF)			// Utiliza Vale Presente
Local lAutoExB	:= IsBlind()																// Verifica se a rotina sera executada via execauto ou nao

If nPos > 0
	If AllTrim(Upper(aFormPgtos[nPos][1]))$ cFormVale
		lRet := .T.
		If !lAutoExB
			oCart:Show()
			oIDCart:Show()
		EndIf
	Else
		cFormaID := If(lVisuSint,Space(TamSX3("L4_FORMAID")[1]),Space(01))
		lRet 	 := .F.
		If !lAutoExB
			oCart:Hide()
			oIDCart:Hide()
		EndIf
	EndIf
EndIf

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ValidIDºAutora ³ Vendas Clientes    º Data ³  11/04/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida se o dígito informado é correto para o controle de  º±±
±±º          ³ múltiplos cartões                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7ValidID(	cForma, cFormaId, lTefPendCS, cBkpID,;
							cBkpForm )
Local lRet 	 	:= .T.
Local nPos 	 	:= Ascan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})
Local cCond  	:= If(nPos>0,AllTrim(Upper(aFormPgtos[nPos][1])),Space(02))
Local nPosId 	:= Ascan(aPgtosSint,{|x| Alltrim(Upper(x[4]))==Alltrim(Upper(cFormaID));
									 .AND. Alltrim(x[1])==Alltrim(cCond) })
Local lAutoExB	:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao

Default lTefPendCS 	:= .F.
Default cBkpID		:= ""
Default cBkpForm	:= ""

// Se for TEF Discado, a validacao e feita somente pelo ID e nao ID + Forma.
// Deste modo, quando for TEF Discado, nao sera permitido repetir o ID em formas diferentes.
If cTipTef == TEF_DISCADO
	nPosId 	:= Ascan(aPgtosSint,{|x| Alltrim(Upper(x[4]))==Alltrim(Upper(cFormaID)) })
Endif

If cCond $ _FORMATEF
	If Empty(cFormaId)
		If !lAutoExB
			MsgAlert(STR0110,STR0001) //"Informe o ID do Cartão para a operação TEF.","Atenção"
		Else
			ConOut(STR0110) //"Informe o ID do Cartão para a operação TEF.","Atenção"
		EndIf
		lRet := .F.
	ElseIf nPosId > 0	 // Mantido somente a variável que possui a posição do Id do cartão no aPgtosSint, para não ocorrer repetição.
		If AllTrim(cFormaID) <> AllTrim(cBkpID) .OR. AllTrim(cCond) <> AllTrim(cBkpForm) // Somente reclama se for uma alteracao mesmo do ID ou forma
			If !lAutoExB
				MsgAlert(STR0156, STR0001)// "Já existe uma transação pendente para este cartão. Altere a sequência ou clique em Zere Pagamentos para reiniciar a negociação.","Atenção"
			Else
				ConOut(STR0156)// "Já existe uma transação pendente para este cartão. Altere a sequência ou clique em Zere Pagamentos para reiniciar a negociação.","Atenção"
			EndIf
			lRet := .F.
		EndIf
	EndIf
EndIf

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7WhenChIDºAutora ³ Vendas Clientes    º Data ³  06/08/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se eh necessaria a digitacao do digito de controle º±±
±±º          ³ de cheques                                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7WhenChID(nLinha, cForma, cChequeID)
Local lRet 		:= .F.
Local nPos 		:= Ascan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})

If nPos > 0
	If cPaisLoc == "ARG" .AND. AllTrim(Upper(aFormPgtos[nPos][1]))$"CH"
		lRet := .T.
	Else
		cChequeID := IIf(SL4->(FieldPos("L4_CHEQID"))>0,Space(TamSX3("L4_CHEQID")[1]),Space(01))
		lRet 	 := .F.
	EndIf
EndIf

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ValChIDºAutora ³ Vendas Clientes    º Data ³  06/08/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida se o dígito informado é correto para o controle de  º±±
±±º          ³ múltiplos cheques                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7ValChID(cForma, cChequeID)
Local lRet 	 	:= .T.
Local nPos 	 	:= Ascan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})
Local cCond  	:= If(nPos>0,AllTrim(Upper(aFormPgtos[nPos][1])),Space(02))
Local nPosId 	:= Ascan(aPgtosSint,{|x| Alltrim(Upper(x[7]))==Alltrim(Upper(cChequeID))})
Local lAutoExB	:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao

If cCond $ "CH"
	If Empty(cChequeID)
		If !lAutoExB
			MsgAlert(STR0172,STR0001) //"Informe o ID do Cheque para a operação.","Atenção"
		Else
			Conout(STR0172)
		Endif
		lRet := .F.
	ElseIf nPosId > 0
		If !lAutoExB
			MsgAlert(STR0173, STR0001)// "Já existe uma transação para este cheque. Altere a sequência ou clique em Zere Pagamentos para reiniciar a negociação.","Atenção"
		Else
			Conout(STR0173)
		Endif
		lRet := .F.
	EndIf
EndIf

Return(lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7_VldAdmºAutora ³ Vendas Clientes    º Data ³  09/12/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se a administrador e administrador de vale compra º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LJ7_VldAdm( cCodAdmin )
Local lRet := .F.

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se a administradora informada controla Vale-compras         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SAE->( FieldPos( "AE_VCOMPRA" ) ) > 0
	If Posicione( "SAE", 1, xFilial("SAE") + cCodAdmin, "SAE->AE_VCOMPRA" ) == "1"
		lRet := .T.
	EndIf
EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7RetFato³ Autor	³ Vendas Clientes       ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³Retorna o fator cadastrado para uma condicao de pagto. 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³Lj7RetFator(ExpC1, ExpC2, ExpN1)						  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpC1 := Cod. da Adm. Financeira				              ³±±
±±³          ³ ExpC2 := Cod. da condicao de pagamento                     ³±±
±±³          ³ ExpN1 := Fator de financiamento				              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³ LOJA701                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RetFator( cCodFin , cCondicao, nFator )

Local lRet		:= .T.			//variav. de retorno da funcao
Local aArea		:= GetArea()	//guarda a area atual
Local lAutoExB	:= IsBlind()	// Verifica se a rotina sera executada via execauto ou nao

DbSelectArea("SAF")
DbSetOrder(1)

If DbSeek( xFilial( "SAF" ) + cCodFin + cCondicao )
	nFator := SAF->AF_FATOR
Else

	// A condi‡„o de pagamento atual n„o cont‚m
	// fator financeiro para a administradora escolhida.
	// Escolha outra condi‡„o, e caso n„o exista nenhuma, favor cadastra-l 
	// previamente.
	// Aten‡„o
	If !lAutoExB
		MsgInfo(STR0116 + STR0117 + STR0118 + STR0119 ,;
				STR0001)
	Else
		ConOut(STR0116 + STR0117 + STR0118 + STR0119)
	EndIf
	nFator := 0
	lRet := .F.
EndIf

RestArea(aArea)

Return lRet



/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7Fator	³ Autor ³ Vendas Clientes       ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³Calcula e mostra em tela as parcelas com fator multiplicador³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³Lj7Fator(ExpO1, ExpL1, ExpN1, ExpC1)						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpO1 := Dialog da janela principal 			              ³±±
±±³          ³ ExpL1 := Usou fator  (.T. ou .F.)                          ³±±
±±³          ³ ExpN1 := Fator de financiamento				              ³±±
±±³          ³ ExpC1 := Adm. financeira        			              	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³Loja701                                                     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7Fator(oDlgLoja,	lUsouFator,	nFator,	cAdmFator)

Local oBtn1								//Botao OK
Local oBtn2								//Botao Cancel
Local oCbxFat							//ComboBox das Administradoras
Local cCbxFat		:= ""				//Adm. selecionada
Local aCbxFat	 	:= {}             	//Array da administradoras
Local nTotFat	 	:= Lj7T_Total( 2 )	//Total da Venda
Local nLiq			:= nTotFat			//Total liquido
Local nNumParc 		:= 0				//Nr. de parcelas financiadas
Local nNumParcelas	:= Len(aPgtos)		//Nr. de parcelas origem
Local cCondicao 	:= ""            	//Descr. da condicao de pagto
Local cCondPag  	:= M->LQ_CONDPG		//Condicao de pagto informada
Local lFinPro	 	:= .F.				//Indica se eh financiamento proprio
Local nEntrada	 	:= 0				//Vlr. de Entrada
Local nFinanciado   := 0 				//Vlr. Financiado
Local cTipoJuros	:= ""				//Tipo de Juros
Local nX			:= 1				//variav. auxiliar em lacos For...Next
Local nTamAE_COD    := TamSX3("AE_COD")[1] // Tamanho do campo AE_COD
Local lCarVarFat 	:= .F.				// Retorno da funcao Lj7CarVarFat

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao podera entrar nesta condicao, caso o valor das compras seja 0 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nTotFat == 0
	Help(" ","1","SEMVALOR")
	Return Nil
EndIf

If Empty(M->LQ_CONDPG) .OR. M->LQ_CONDPG == "CN "
	M->LQ_CONDPG	:= Space(nTamAE_COD)
	cCondPag  		:= M->LQ_CONDPG
Else
	cCondicao := Posicione("SE4",1,xFilial("SE4")+M->LQ_CONDPG,"SE4->E4_DESCRI")
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se tem parc. de entrada  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX:=1 to Len(aPgtos)
	If aPgtos[nX,1] == dDataBase
		nEntrada += aPgtos[nX,2]
	EndIf
Next nX

nFinanciado := nTotFat - nEntrada

// Administradora
DEFINE MSDIALOG oDlgFator FROM  34,155 TO 170,335 ;
TITLE STR0120 PIXEL OF oDlgLoja

// Administradora
@ 4, 4 TO 46, 85 LABEL STR0120 OF oDlgFator	PIXEL

@ 20, 12 COMBOBOX oCbxFat VAR cCbxFat ITEMS aCbxFat SIZE 63, 35 ;
OF oDlgFator PIXEL

DEFINE SBUTTON oBtn1 FROM 50,020 TYPE 1 ENABLE;
ACTION If(Lj7RetFator(Substr(cCbxFat,1,3), cCondPag, @nFator ),;
(If(Lj7ShowFator(oDlgLoja		,@nTotFat		,@nNumParc		,@nFator,;
				  @cCondicao	,@cCbxFat		,@cCondPag		,@nEntrada,;
				  @nFinanciado	,@cTipoJuros	,@lFinPro		,@lUsouFator,;
				  @nLiq			,@nNumParcelas	,@cAdmFator		,oDlgFator),;
oDlgFator:End(),)),.T.) ;
OF oDlgFator PIXEL

DEFINE SBUTTON oBtn2 FROM 50,055 TYPE 2 ENABLE ACTION oDlgFator:End( ) OF oDlgFator PIXEL

lCarVarFat := Lj7CarVarFat(	@nTotFat	,@nNumParc	,@cCondPag	,@aCbxFat,;
				 			@cCbxFat	,@nFator	,oCbxFat)
If lCarVarFat
	ACTIVATE MSDIALOG oDlgFator CENTER ON INIT .T.
Else
	ACTIVATE MSDIALOG oDlgFator CENTER ON INIT oDlgFator:End()
EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7CarVarFat³Autor³ Vendas Clientes       ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³Verifica se todas as vari veis necess rias para o financia- ³±±
±±³          ³mento existem.                                              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³Lj7Fator(ExpN1, ExpN2, ExpC1, ExpA1, ExpC2, ExpN3, ExpO1)	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpN1 := Total Fator                			              ³±±
±±³          ³ ExpN2 := Nr. de parcelas                                   ³±±
±±³          ³ ExpC1 := Condicao de pagto     				              ³±±
±±³          ³ ExpA1 := Array das adm. financeiras		              	  ³±±
±±³          ³ ExpC2 := Adm. selecionada no combobox	              	  ³±±
±±³          ³ ExpN3 := Fator de financimento     		              	  ³±±
±±³          ³ ExpO1 := Objeto combobox de adm. financ.	             	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ .T. ou .F.                                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³ Loja701                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CarVarFat(nTotFat	,nNUmParc	,cCondPag	,aCbxFat,;
					 cCbxFat	,nFator		,oCbxFat )

Local lRet		:= .T.			//retorno da funcao
Local lAutoExB	:= IsBlind()	// Verifica se a rotina sera executada via execauto ou nao

aCbxFat	 := Lj010LerCart("FI",.T.)
If Empty( aCbxFat )

	// N„o existem administradoras de financiamento habilitadas
	// a utilizar Fator. Incluir uma adminitradora e cadastrar os fatores
	// referˆntes a ela.
	If !lAutoExB
		MsgInfo( STR0121 + STR0122 + STR0123 )
	Else
		ConOut( STR0121 + STR0122 + STR0123 )
	EndIf
	lRet := .F.
Else
	oCbxFat:SetItems( aCbxFat )
	cCbxFat := aCbxFat[1]
	oCbxFat:Refresh()
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7ShowFator³Autor³ Vendas Clientes       ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³Mostra na tela as parcelas e totais do financiamento.       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7ShowFator(ExpO1, ExpN1, ExpN2, ExpN3, ExpC1, ExpC2,;    ³±±
±±³          ³              ExpC3, ExpN4, ExpN5, ExpC4, ExpL1, ExpL2,;    ³±±
±±³          ³              ExpL3, ExpN6, ExpC5, ExpO1)                   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpO1 := Dialog da janela principal 			              ³±±
±±³          ³ ExpN1 := Total Fator                                       ³±±
±±³          ³ ExpN2 := Nr. de parcelas financiadas				          ³±±
±±³          ³ ExpN3 := Fator financeiro      				              ³±±
±±³          ³ ExpC1 := Descr. da condicao de pagto     				  ³±±
±±³          ³ ExpC2 := Adm. selecionada no combobox			          ³±±
±±³          ³ ExpC3 := Condicao de pagto     				              ³±±
±±³          ³ ExpN4 := Valor da entrada      				              ³±±
±±³          ³ ExpN5 := Valor Financiado      				              ³±±
±±³          ³ ExpC4 := Tipo de Juros         				              ³±±
±±³          ³ ExpL1 := Financiamento proprio (.T. ou .F.)                ³±±
±±³          ³ ExpL2 := Indica se usou fator (.T. ou .F.)				  ³±±
±±³          ³ ExpL3 := Valor liquido da venda   				          ³±±
±±³          ³ ExpN6 := Nr. de parcelas       				              ³±±
±±³          ³ ExpC5 := Administradora com fator			              ³±±
±±³          ³ ExpO1 := Dialog da tela de Fator 			              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³Loja701                                                     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ShowFator(oDlgLoja		,nTotFat		,nNumParc	,nFator,;
                   	cCondicao		,cCbxFat		,cCondPag	,nEntrada,;
                   	nFinanciado		,cTipoJuros		,lFinPro	,lUsouFator,;
                   	nLiq			,nNumParcelas	,cAdmFator	,oDlgFator)

Local oDlgShow			//Dialog principal
Local oLbxFat			//Listbox das parcelas com fator
Local oCondPag			//Exibe cond. de pagto
Local oBtn1				//Botao confirma
Local oBtn2				//Botao cancel
Local oTotFat			//Exibe total com fator
Local oNumParc			//Exibe nr. de parcelas
Local oFator            //Exibe fator usado
Local oFnt1				//Tipo de fonte usada
Local oCondicao			//Exibe cod. da condicao de pagto
Local nI            := 1  											//variav. auxiliar
Local aArea			:= GetArea()									//guarda a area atual
Local lRet 			:= .F.											//retorno da funcao
Local aLbxFat		:= {}											//array das parcelas com fator
Local cAdmin   		:= Substr( cCbxFat , 7, Len(cCbxFat ) )		//descricao da administradora
Local cCodAdm   	:= Substr( cCbxFat ,1,3)						//cod. da administradora
Local aValores  	:= {}											//array das parcelas recalculadas
Local nTotFatTel	:= 0											//valor total com aplicacao do fator
Local nDiasVenc		:= 0											//Dias para vencto
Local lLjAdmFin 	:= ExistBlock("LJ7034")							//PE que retorna a taxa administrativa
Local nTaxaJur  	:= 0											//taxa de juros
Local dDataAnt     	:= MsDate()										//data anterior
Local nNaoFinanc	:= 0											//valor total nao-financiado
Local lContinua 	:= .T.											//indica se continua a operacao
Local nSobraNCC 	:= 0											//Valor restante da NCC
Local nValICMSSol	:= 0											//Valor do ICMS solid.
Local nVlrFSD		:= Lj7CalcFrete()								//Valor de Frete/Seguro/Despesa
Local nVlrBase		:= 0											//Valor base para uso na LJ7CalcPgt
Local lAutoExB		:= IsBlind()									// Verifica se a rotina sera executada via execauto ou nao
Local lFtAdmFin 		:= ExistBlock("FTVD7034")							//PE que retorna a taxa administrativa
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida


DbSelectArea("SAE")
DbSetOrder(1)
DbSeek( xFilial("SAE") + cCodAdm )

If (SAE->AE_USAFATO == "S" .AND. AllTrim(SAE->AE_TIPO) == "FI") .AND. aPgtos[1,3] <> "FI"
   lContinua:= .F.
EndIf

If lContinua

	lFinPro := ( Upper( AllTrim( SAE->AE_FINPRO)) == "S" )
	nDiasVenc := SAE->AE_VENCFIN

	If (nEntrada > 0) .AND. (aPgtos[1][3] <> "FI")
		nTotFat:= nTotFat - nEntrada
		lEntFin:= .F.
	Else
		lEntFin:= .T.
	EndIf

	If lLjAdmFin .AND. !lFtvdVer12
		nTaxaJur := ExecBlock("LJ7034",.F.,.F.,{cCodAdm})
		nTotFat += nTaxaJur
	EndIf

	If lFtAdmFin .AND. lFtvdVer12
		nTaxaJur := ExecBlock("FTVD7034",.F.,.F.,{cCodAdm})
		nTotFat += nTaxaJur
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Chama a funcao para calculo das parcelas, e tira o frete e a NCC Usada   ³
	//³ para nao entrar no calculo de juros                                      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc == "BRA"
		dDataAnt := aPgtos[1][1]

		nSobraNCC 	:= If(nNCCUsada-(LJ7T_SubTotal(2)-(LJPCCRet()+ If( LjxDAbISS(), MaFisRet(,'NF_VALISS'), 0 )))>0, (LJ7T_SubTotal(2)-(LJPCCRet()+ If( LjxDAbISS(), MaFisRet(,'NF_VALISS'), 0 ))), nNCCUsada)
		If MaFisFound("NF")
			nValICMSSol := Lj7IcmsSol()
		Else
			nValICMSSol :=  0
		EndIf

		nVlrBase	:= ( Lj7T_Subtotal( 2 ) - (LJPCCRet()+ If( LjxDAbISS(), MaFisRet(,'NF_VALISS'), 0 ))) - LJ7T_DescV( 2 ) - nVlrFSD - nSobraNCC
		aValores    := Lj7CalcPgt(nVlrBase		,cCondPag	,NIL	,nVlrFSD,;
								  NIL			,NIL		,NIL	,nValICMSSol)

		//Calculo antigo (V.Balcao)
		//aValores := Condicao( nLiq, cCondPag,,, nRetICMS )

		If nEntrada > 0
			aValores[1][1] := dDataAnt
		EndIf
	Else

		aValores := Lj7CalcPgt( Lj7T_Total(2)	,cCondPag	,NIL	,nVlrFSD,;
								NIL				,NIL		,nMoedaCor)

	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza o campo da Administr. Financeira  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	cAdmFator 		:= cCodAdm
	M->LQ_ADMFIN	:= cAdmFator

	nNumParc:= 0
	For nI:= 1 To Len(aPgtos)
		If (AllTrim(aPgtos[nI][3]) == "FI")
			nNumParc++
		Else
			nNaoFinanc += aPgtos[nI][2]
		EndIf
	Next nI

	If nEntrada > 0
		nNaoFinanc -= nEntrada

		If nNaoFinanc < 0
			nNaoFinanc := 0
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Retorna array com as parcelas calculadas ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aLbxFat := Lj7CalcFatWin(aValores	,nEntrada	,(nTotFat-nNaoFinanc)	,nNumParc,;
							cCondPag	,cCodAdm	,nFator)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Recalcula o valor total ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nTotFatTel := 0
	Aeval( aLbxFat, { |x| nTotFatTel += x[2] } )

	DEFINE FONT oFnt1 NAME "Arial" SIZE 8.5,14 BOLD // Largura x Altura

	// Financiamento
	DEFINE MSDIALOG oDlgShow FROM  34,155 TO 326,567 ;
	TITLE STR0124 PIXEL OF oDlgFator

	@ 4, 5 TO 56, 200 LABEL "" OF oDlgShow  PIXEL

	// Detalhes
	@ 61,5 TO 92, 102 LABEL STR0125 OF oDlgShow  PIXEL

	// Condicao de pagamento:
	@ 69, 9 SAY STR0126 SIZE 65, 7 OF oDlgShow PIXEL
	@ 67, 77 MSGET oCondPag Var cCondPag SIZE 15, 08 WHEN .F. ;
	OF oDlgShow PIXEL

	// Financiamento Pr¢prio ?
	// Sim / N„o
	@ 80, 9 SAY STR0127 +;
	If(lFinPro,STR0061,STR0128) SIZE 85,7 OF oDlgShow PIXEL

	// Administradora
	@ 98,5 TO 126, 102 LABEL STR0120 OF oDlgShow  PIXEL

	@ 109, 9 SAY cAdmin SIZE 80,15 OF oDlgShow PIXEL COLOR CLR_BLUE FONT oFnt1

	// Data / Valor a pagar
	@ 63,105 LISTBOX oLbxFat FIELDS HEADER STR0129,STR0130 ;
	SIZE 95,64 OF oDlgShow PIXEL
	oLbxFat:SetArray( aLbxFat )
	oLbxFat:bline := {|| {aLbxFat[oLbxFat:nAt,1],;
	TransForm(aLbxFat[oLbxFat:nAt,2], PesqPict("SL1","L1_VLRTOT",,nMoedaCor))} }
	//Datas e Valores a Pagar
	oLbxFat:cToolTip := STR0131
	//oLbxFat:aJustify := { .T.,.T. } protheus

	@ 12, 64 SAY oTotFat   VAR nTotFatTel SIZE 73, 10 OF oDlgShow PIXEL RIGHT;
	PICTURE PesqPict("SL1","L1_VLRTOT",,nMoedaCor) COLOR CLR_HRED FONT oFnt1
	@ 22, 64 SAY oNumParc  VAR nNumParc  SIZE 73, 10 OF oDlgShow PIXEL RIGHT FONT oFnt1 COLOR CLR_BLUE
	@ 32, 64 SAY oFator	  VAR nFator	 SIZE 73, 10 OF oDlgShow PIXEL RIGHT FONT oFnt1 COLOR CLR_BLUE PICTURE "@E 9.999999999"
	@ 42, 64 SAY oCondicao VAR cCondicao SIZE 73, 10 OF oDlgShow PIXEL RIGHT FONT oFnt1 COLOR CLR_BLUE

	@ 12, 9 SAY STR0132 SIZE 18, 7 OF oDlgShow PIXEL  // Total:
	@ 22, 9 SAY STR0133 SIZE 28, 7 OF oDlgShow PIXEL  // Parcelas:
	@ 32, 9 SAY STR0134 SIZE 18, 7 OF oDlgShow PIXEL  // Fator:
	@ 42, 9 SAY STR0135 SIZE 30, 7 OF oDlgShow PIXEL  // Condi‡Æo:

	DEFINE SBUTTON oBtn1 FROM 132,136 TYPE 1 ENABLE ACTION ;
	(lRet := .T.,Lj7AtuVend(@aLbxFat,		@nEntrada,  @nFinanciado,  @cTipoJuros,;
						  	nTotFatTel, 	@lFinPro,   nNumParc,      nFator,;
						  	@lUsouFator,	@nLiq,		cCondPag,		nDiasVenc,;
						  	@nNumParcelas,	aValores,	nSobraNCC),;
	oDlgShow:End( )) OF oDlgShow PIXEL

	DEFINE SBUTTON oBtn2 FROM 132,168 TYPE 2 ENABLE ACTION ;
	(lRet := .F.,nTotFat -= nTaxaJur,If(!lEntFin,nTotFat += nEntrada,),oDlgShow:End( )) OF oDlgShow PIXEL

	ACTIVATE MSDIALOG oDlgShow CENTER

	RestArea( aArea )

Else
	//A Condicao de Pagamento não condiz com o Tipo de Administradora selecionada. A condicao de pagamento tem que ser do tipo FI,Atencao
	If !lAutoExB
		MsgInfo(STR0136+;
				STR0137,STR0001)
	Else
		ConOut(STR0136+STR0137)
	EndIf
EndIf


Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7AtuVend³ Autor ³ Vendas Clientes       ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Atualiza dados na tela c/ os valores calculados pelo fator ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³   Lj7AtuVend(ExpA1, ExpN1, ExpN2, ExpC1, ExpN3, ExpL1,;    ³±±
±±³          ³              ExpN4, ExpN5, ExpL2, ExpN6, ExpC2, ExpN7,;    ³±±
±±³          ³              ExpN8, ExpA2, ExpN9)		                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpA1 := Array das administradoras  			              ³±±
±±³          ³ ExpN1 := Valor de entrada                                  ³±±
±±³          ³ ExpN2 := Valor financiado              			          ³±±
±±³          ³ ExpC1 := Tipo de Juros                 			          ³±±
±±³          ³ ExpN3 := Total com fator               			          ³±±
±±³          ³ ExpL1 := Financiamento proprio (.T. ou .F.)			      ³±±
±±³          ³ ExpN4 := Nr. de parcelas financiadas   			          ³±±
±±³          ³ ExpN5 := Fator financeiro              			          ³±±
±±³          ³ ExpL2 := Indica se usou fator          			          ³±±
±±³          ³ ExpN6 := Valor liq. da venda           			          ³±±
±±³          ³ ExpC2 := Cond. de pagto                			          ³±±
±±³          ³ ExpN7 := Dias de vencto                			          ³±±
±±³          ³ ExpN8 := Nr. de parcelas               			          ³±±
±±³          ³ ExpA2 := array com as parcelas recalculadas		          ³±±
±±³          ³ ExpN9 := Valor restante de NCC          			          ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³LOJA701                                                     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7AtuVend(aLbxFat		,	nEntrada,	nFinanciado	,	cTipoJuros	,;
					nTotFatTel	,	lFinPro	,	nNumParc	,	nFator		,;
					lUsouFator	,	nLiq	,	cCondPag	,	nDiasVenc	,;
					nNumParcelas,	aValores,	nSobraNCC)

Local nAuxFor		:= 0						// Variavel para auxiliar o For...Next
Local aLbxFatBk		:= aClone( aLbxFat )		// Clone do array aLbxFat
Local nPosFat		:= 0						// Contador de quantas vezes entrou como <> de "FI"
Local nNaoFinanc	:= 0						// Acumulador do valor nao financiado
Local nVlrAux		:= 0                       	// Variavel auxiliar de totalizador
Local nValFrete		:= 0						// Valor do Frete
Local nVlrSub		:= 0						// Sub Total da Venda
Local nDifNCCTot	:= 0						// Diferença entre NCCs e Total da Venda
Local nValAbISS		:= 0						// Valor do ISS

lUsouFator	:= .T.
M->LQ_FATOR	:= nFator

aLbxFat		:= {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama a funcao para calculo das parcelas, e tira o frete e a NCC Usada   ³
//³ para nao entrar no calculo de juros                                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If LJ220AbISS()
   nValAbISS := MaFisRet(,'NF_VALISS')
EndIf

For nAuxFor := 1 to Len( aPgtos )

	If AllTrim(aPgtos[nAuxFor][3]) <> "FI"
		AAdd( aLbxFat,{ aPgtos[nAuxFor][1], aPgtos[nAuxFor][2], aPgtos[nAuxFor][3] } )
		nNaoFinanc += aPgtos[nAuxFor][2]
		nPosFat    += 1
	Else
		AAdd( aLbxFat,{ aLbxFatBk[nAuxFor-nPosFat][1], aLbxFatBk[nAuxFor-nPosFat][2], "FI" } )
	EndIf

Next nAuxFor

If lFinPro
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza o valor financiado ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nFinanciado := 0
	nEntrada	:= 0

	For nAuxFor :=1 To Len( aLbxFat )

		If aLbxFat[nAuxFor][1] > dDataBase
			nFinanciado += aLbxFat[nAuxFor][2]

		ElseIf aLbxFat[nAuxFor][1] == dDataBase
			nEntrada += aLbxFat[nAuxFor][2]
		EndIf

	Next nAuxFor

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Calcula a taxa de juros  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nTxJuros  	:= NoRound( ( ( (  nFinanciado + nEntrada ) - ( nLiq ) ) * 100 ) / ( nLiq ),2 )
	M->LQ_JUROS	:= nTxJuros

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Zera o array aPgtos para gravar o novo calculo ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aPgtos := {}
	nVlrAux := 0

	For nAuxFor := 1 To Len( aLbxFat )
		AAdd(aPgtos , { aLbxFat[nAuxFor][1],;
						aLbxFat[nAuxFor][2],;
						aLbxFat[nAuxFor][3],;
						{},;
						NIL,;
						If(cPaisLoc<>"BRA",aValores[nAuxFor][_MOEDA],1)	,;
						If(cPaisLoc<>"BRA",aValores[nAuxFor][_EMISSAO],NIL),;
						If(AllTrim(aLbxFat[nAuxFor][3])$_FORMATEF,"1",Space(01)),;
						Space(01),;
						0 } )

		nVlrAux += aLbxFat[nAuxFor][2]
	Next nAuxFor

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza Total	 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

    nValFrete   := Lj7CalcFrete()
    lCalcFrete := .F.
	nVlrSub		:= LJ7T_SubTotal(2) - ( LJPCCRet() + nValAbISS )
	nDifNCCTot	:= nSobraNCC
    If nNCCUsada >= (nVlrSub + nValFrete)
		nDifNCCTot := nVlrSub + nValFrete
    EndIf

	Lj7T_Total( 2, ( nVlrAux + nDifNCCTot + LJPCCRet() + If( LJ220AbISS(), MaFisRet(,'NF_VALISS'), 0 ) ))

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza Parcelas ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7T_TotPar( 2, nVlrAux )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Alimenta o array de acrescimo. Avalia se o desconto foi concedido antes³
	//³ou depois do acrescimo.                                                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If M->LQ_JUROS > 0
		aAcrescimo[1] := nNCCUsada + nVlrAux - Lj7T_SubTotal(2) + If(aDesconto[1]==1,aDesconto[3],0) 	// Valor do acrescimo
		aAcrescimo[2] := M->LQ_JUROS		// Percentual do acrescimo
	Else
		aAcrescimo[1] := 0					// Valor do acrescimo
		aAcrescimo[2] := 0					// Percentual do acrescimo
	EndIf
Else
	nTxJuros	:= 0
	//nVlrAcrs	:= 0
	nNumParcelas:= 1

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se existe entrada ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If aLbxFat[1][1] == dDataBase .AND. !lEntFin
		nEntrada	:= aLbxFat[1][2]
		nNumParcelas+= 1
		nFinanciado	:= nLiq - nEntrada
	Else
		nFinanciado	:= nLiq
		nEntrada	:= 0
	EndIf
EndIf

oPgtos:SetArray( aPgtos )

oPgtos:bLine := {||{aPgtos[oPgtos:nAt,1],;
					Transform(aPgtos[oPgtos:nAt,2],PesqPict("SL1","L1_VLRTOT",,aPgtos[oPgtos:nAt,4])),;
					aPgtos[oPgtos:nAt,3],aPgtos[oPgtos:nAt,4]}}

oPgtos:Refresh()


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se estiver usando visualiz. sintetica atualiza o array/browse sintetico ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lVisuSint
	aPgtosSint := Lj7MontPgt(aPgtos)
	oPgtosSint:SetArray( aPgtosSint )
	oPgtosSint:Refresh()
EndIf

aParcTef := aClone( aPgtos )

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7ImpFatWin ³ Autor ³ Vendas Clientes    ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³Imprime os dados do finaciamento (fator)                    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7ImpFatWin(ExpC1, ExpN1)							      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpC1 := Condicao de pagto          			              ³±±
±±³          ³ ExpN1 := Valor Total da venda                              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³Loja701                                                     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ImpFatWin( cCondicao, nValorBase )
Local aArea 		:= GetArea()			//guarda a area atual
Local lScrImp	 	:= If(ExistBlock("LJ7035"), .T., .F.)	//indica se existe o PE de impressao
Local nI 		 	:= 0					//variav. auxiliar em lacos For..next
Local aFatorTmp 	:= {}					//array das parcelas com fator
Local nFator	 	:= SL1->L1_FATOR		//Fator financ.
Local cCodAdm	 	:= SL1->L1_ADMFIN		//Adm. financ.
Local cCondPag  	:= SL1->L1_CONDPG		//Cond. de pagto
Local nTotFat	 	:= nValorBase			//Valor da venda
Local nNumParc  	:= SL1->L1_PARCELAS		//Nr. de parcelas
Local nEntrada 		:= SL1->L1_ENTRADA		//Valor da entrada
Local aValores 		:= {}					//array das parcelas recalculadas
Local nSobraNCC 	:= 0					//Valor restante da NCC
Local nValICMSSol	:= 0					//Valor do ICMS solid.
Local nVlrFSD		:= Lj7CalcFrete()		//Valor de Frete/Seguro/Despesa
Local nVlrBase		:= 0					//Valor base para uso na LJ7CalcPgt
Local aParFator 	:= {} 					//Array usado dentro do ExecBlock LJ7035
Local lAutoExB 		:= IsBlind()	   		// Verifica se a rotina sera executada via execauto ou nao
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

// Deseja imprimir o comprovante de
// Financiamento ?
// Impress„o

If !lAutoExB .And. MsgYesNo( STR0138 + STR0139 , STR0140 ) .AND. Lj010InitPrint("O")

	If cPaisLoc == "BRA"

		nSobraNCC 	:= If(nNCCUsada-(LJ7T_SubTotal(2)-(LJPCCRet()+ If( LjxDAbISS(), MaFisRet(,'NF_VALISS'), 0 )))>0, (LJ7T_SubTotal(2)-(LJPCCRet()+ If( LjxDAbISS(), MaFisRet(,'NF_VALISS'), 0 ))), nNCCUsada)
		nValICMSSol := If( MaFisFound("NF"), Lj7IcmsSol(), 0 )

		nVlrBase	:= ( Lj7T_Subtotal( 2 ) - (LJPCCRet()+ If( LjxDAbISS(), MaFisRet(,'NF_VALISS'), 0 ))) - LJ7T_DescV( 2 ) - nVlrFSD - nSobraNCC
		aValores    := Lj7CalcPgt( nVlrBase		,cCondicao	,NIL	,nVlrFSD,;
									NIL			,NIL		,NIL	,nValICMSSol)

	Else

		aValores := Lj7CalcPgt( Lj7T_Total(2)	,cCondicao	,NIL	,nVlrFSD,;
								NIL				,NIL		,nMoedaCor)

	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Retorna array com as parcelas calculadas ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aFatorTmp := Lj7CalcFatWin( aValores	,nEntrada	,nTotFat	,nNumParc,;
								cCondPag	,cCodAdm	,nFator)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Carrega array para impressao no Execblock ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nI := 1 to Len( aFatorTmp )
		Aadd( aParFator,{Dtoc(aFatorTmp[nI,1]) + " - " + Transform(aFatorTmp[nI,2], "@E 99,999,999.99")})
	Next nI

	If lScrImp .AND. !lFtvdVer12
		ExecBlock("LJ7035",.F.,.F.,{aParFator})
	ElseIf !lFtvdVer12
		// Script de impress„o para o comprovante
		// de financiamento n„o exite - Verifique se o arquivo
		// IMPFATOR.PRX e IMPFATOR._IW est„o no diret¢rio das
		// Tabelas de configuracao do Sistema. Normalmente \SIGAADV\.
		MsgStop(STR0141 + STR0142 + STR0143 + STR0144)
	EndIf

	If lScrImp .AND. lFtvdVer12
		ExecBlock("FTVD7035",.F.,.F.,{aParFator})
	ElseIf lFtvdVer12
		// Script de impress„o para o comprovante
		// de financiamento n„o exite - Verifique se o arquivo
		// IMPFATOR.PRX e IMPFATOR._IW est„o no diret¢rio das
		// Tabelas de configuracao do Sistema. Normalmente \SIGAADV\.
		MsgStop(STR0141 + STR0142 + STR0143 + STR0144)
	EndIf

	Lj010EndPrint("O")
EndIf

RestArea( aArea )

Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7CalcFatWin³Autor³ Vendas Clientes      ³ Data ³ 11/01/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³Calcula as parcelas com fator multiplicador.				  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7CalcFatWin(ExpA1,ExpN1,ExpN2,ExpN3,ExpC1,ExpC2,ExpN4)   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpA1 := Array com as parcelas      			              ³±±
±±³          ³ ExpN1 := Valor da Entrada                                  ³±±
±±³          ³ ExpN2 := Valor Total com fator                             ³±±
±±³          ³ ExpN3 := Nr. de parcelas                                   ³±±
±±³          ³ ExpC1 := Condicao de pagto                                 ³±±
±±³          ³ ExpC2 := Cod. da adm. financeira                           ³±±
±±³          ³ ExpN4 := Fator financeiro                                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno	 ³ExpA1 - Parcelas em um array multidimencional (Data - Valor)³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³SigaLoja													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CalcFatWin( aValores	,nEntrada	,nTotFat	,nNumParc,;
						cCondPag	,cCodAdm	,nFator)

Local aParcFat   := {}						//Array das parcelas com fator mult.
Local aArea 	 := GetArea()				//Guarda a area anterior
Local nTotalRes  := 0						//Valor total auxiliar
Local nDif		 := 0						//Valor de diferenca das parcelas
Local cIncideEnt := 0						//Indica se incide na entrada
Local cTipoFin   := SuperGetMV("MV_TPFATOR")//Tipo de Fator no Total ou por Parcelas
Local lLjAdmTax  := ExistBlock("LJ7034")	//PE que retorna a taxa administrativa
Local nAdmTax    := 0						//Taxa administrativa
Local lArreFin   := SuperGetMV("MV_ARREFIN")//Tipo de arredondamento financeiro
Local nI         := 0						//variav. usada em lacos for...next
Local lFTAdmTax  	:= ExistBlock("FTVD7034")	//PE que retorna a taxa administrativa
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

If lLjAdmTax .AND. !lFtvdVer12
	nAdmTax:= ExecBlock("LJ7034",.F.,.F.,{cCodAdm})
EndIf

If lFTAdmTax .AND. lFtvdVer12
	nAdmTax:= ExecBlock("FTVD7034",.F.,.F.,{cCodAdm})
EndIf

DbSelectArea("SAF")
DbSetOrder(1)
DbSeek( xFilial("SAF") + cCodAdm + cCondPag )

cIncideEnt := SAF->AF_ENTRADA

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se houver entrada e nao incidir na entrada³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (nEntrada > 0 .AND. lEntFin) .AND. (cIncideEnt <> "S")
	nNumParcRes := nNumParc - 1

	nUnitFat	 	:= nTotFat

	If (cTipoFin == "T")                   //Fator de multiplicacao no total
		nUnitFat	 	:= (nTotFat * nFator)
		nUnitFat		:= ((nUnitFat - nEntrada) / nNumParcRes)

		If lArreFin
			nTotFat	:= Round(( nTotFat * nFator ),2 )
		Else
			nTotFat	:= NoRound(( nTotFat * nFator),2 )
		EndIf

	Else //fator de multiplicacao por parcelas
		nUnitFat		:= ((nUnitFat - nEntrada) / nNumParcRes)

		If lArreFin
			nTotFat	:= Round( (nUnitFat * nNumParcRes * nFator) + nEntrada, 2)
		Else
			nTotFat	:= NoRound( (nUnitFat * nNumParcRes * nFator) + nEntrada, 2)
		EndIf

	EndIf

	If lArreFin
		Aadd( aParcFat , { aValores[1][1],Round(nEntrada + nAdmTax,2) } )
	Else
		Aadd( aParcFat , { aValores[1][1],NoRound(nEntrada + nAdmTax,2) } )
	EndIf

	nTotalRes   := nEntrada
	For nI := 2 to Len(aValores)
		If lArreFin
			If cTipoFin == "T"					//Fator de multiplicacao no total
				Aadd( aParcFat , { aValores[nI][1],Round(nUnitFat + nAdmTax,2) } )
				nTotalRes += Round(nUnitFat,2)
			Else								//Fator de multiplicacao nas parcelas
				Aadd( aParcFat , { aValores[nI][1],Round((nUnitFat + nAdmTax) * nFator ,2) } )
				nTotalRes += Round(nUnitFat * nFator ,2)
			EndIf
		Else
			If cTipoFin == "T"					//Fator de multiplicacao no total
				Aadd( aParcFat , { aValores[nI][1],NoRound(nUnitFat + nAdmTax,2) } )
				nTotalRes += NoRound(nUnitFat,2)
			Else								//Fator de multiplicacao nas parcelas
				Aadd( aParcFat , { aValores[nI][1],NoRound((nUnitFat + nAdmTax) * nFator ,2) } )
				nTotalRes += NoRound(nUnitFat * nFator ,2)
			EndIf
		EndIf
	Next nI

	nNumParcRes := nNumParc
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se houver entrada e incidir na entrada³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (nEntrada > 0 .AND. lEntFin) .AND. (cIncideEnt == "S")
		nNumParcRes := nNumParc

		nUnitFat 	:= nTotFat + nAdmTax

		If (cTipoFin == "T")                 //Fator de multiplicacao no total
			nUnitFat 	:= (nTotFat + nAdmTax) * nFator
			nUnitFat 	:= nUnitFat / nNumParcRes

			If lArreFin
				nTotFat	:= Round(nTotFat * nFator,2)
			Else
				nTotFat	:= NoRound(nTotFat * nFator,2)
			EndIf
		Else                               //Fator de multiplicacao por parcelas
			nUnitFat		:= nUnitFat  / nNumParcRes
			If lArreFin
				nTotFat	:= Round(nUnitFat * nNumParcRes * nFator ,2)
			Else
				nTotFat	:= NoRound(nUnitFat * nNumParcRes * nFator ,2)
			EndIf
		EndIf
		nTotalRes	:= 0

		If lEntFin
			For nI := 1 to Len(aValores)
				If lArreFin
					If cTipoFin == "T"						//Fator de multiplicacao no total
						Aadd( aParcFat , { aValores[nI][1],Round(nUnitFat + nAdmTax,2)} )
						nTotalRes += Round(nUnitFat,2)
					Else									//Fator de multiplicacao nas parcelas
						Aadd( aParcFat , { aValores[nI][1],Round((nUnitFat + nAdmTax) * nFator ,2)} )
						nTotalRes += Round(nUnitFat * nFator ,2)
					EndIf
				Else
					If cTipoFin == "T"						//Fator de multiplicacao no total
						Aadd( aParcFat , { aValores[nI][1],NoRound(nUnitFat + nAdmTax,2)} )
						nTotalRes += NoRound(nUnitFat,2)
					Else									//Fator de multiplicacao nas parcelas
						Aadd( aParcFat , { aValores[nI][1],NoRound((nUnitFat + nAdmTax) * nFator ,2)} )
						nTotalRes += NoRound(nUnitFat * nFator ,2)
					EndIf
				EndIf
			Next nI
		Else
			If lArreFin
				If cTipoFin == "T"							//Fator de multiplicacao no total
					Aadd( aParcFat , { aValores[1][1],Round(nEntrada + nAdmTax,2) } )
				Else										//Fator de multiplicacao nas parcelas
					Aadd( aParcFat , { aValores[1][1],Round((nEntrada + nAdmTax) * nFator ,2) } )
				EndIf
			Else
				If cTipoFin == "T"							//Fator de multiplicacao no total
					Aadd( aParcFat , { aValores[1][1],NoRound(nEntrada + nAdmTax,2) } )
				Else										//Fator de multiplicacao nas parcelas
					Aadd( aParcFat , { aValores[1][1],NoRound((nEntrada + nAdmTax) * nFator ,2) } )
				EndIf
			EndIf

			For nI := 2 to Len(aValores)
				Aadd( aParcFat , { aValores[nI][1],Round(nUnitFat + nAdmTax,2)} )

				If lArreFin
					nTotalRes += Round(nUnitFat,2)
				Else
					nTotalRes += NoRound(nUnitFat,2)
				EndIf
			Next nI

		EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se nao houver entrada ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Else

		nTotFat := nTotFat + nAdmTax

		nNumParcRes := nNumParc

		If lArreFin
			nUnitFat 	:= Round(nTotFat * nFator ,2)	 // Vlr de Cada parc
		Else
			nUnitFat 	:= NoRound(nTotFat * nFator ,2)	 // Vlr de Cada parc
		EndIf

		If (cTipoFin == "T")               //Fator de multiplicacao no total
			nUnitFat := NoRound(nUnitFat / nNumParc,2)

			If lArreFin
				nTotFat  := Round(nTotFat * nFator,2)
			Else
				nTotFat  := NoRound(nTotFat * nFator,2)
			EndIf
		Else                               //Fator de multiplicacao por parcelas
			nTotFat		:= nUnitFat
			If lArreFin
				nUnitFat	:= Round(nUnitFat / nNumParc,2)
			Else
				nUnitFat	:= NoRound(nUnitFat / nNumParc,2)
			EndIf
		EndIf

		nTotalRes	:= 0
		If lEntFin

			For nI := 1 to Len(aValores)
				If Trim(aPgtos[nI][3]) == "FI"
					Aadd( aParcFat , { aValores[nI][1],Round(nUnitFat + nAdmTax,2)} )

					If lArreFin
						nTotalRes += Round(nUnitFat,2)
					Else
						nTotalRes += NoRound(nUnitFat,2)
					EndIf
				EndIf
			Next nI

		Else
			If AllTrim(aPgtos[1][3]) == "FI"
				If lArreFin
					Aadd( aParcFat , { aValores[1][1],Round(nEntrada + If(lEntFin,nAdmTax,0),2) } )
				Else
					Aadd( aParcFat , { aValores[1][1],NoRound(nEntrada + If(lEntFin,nAdmTax,0),2) } )
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Caso exista entrada, realizo o calculo a partir da 2 parcela³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			For nI := 2 to Len(aValores)
				If Trim(aPgtos[nI][3]) == "FI"
					Aadd( aParcFat , { aValores[nI][1],Round(nUnitFat + nAdmTax,2)} )

					If lArreFin
						nTotalRes += Round(nUnitFat,2)
					Else
						nTotalRes += NoRound(nUnitFat,2)
					EndIf
				EndIf
			Next nI

		EndIf
	EndIf
EndIf

If lArreFin
	If Round(nTotFat,2) <> Round(nTotalRes,2)
		nDif := Abs(nTotalRes - nTotFat)
	EndIf
Else
	If Round(NoRound(nTotFat,2),2) <> Round(NoRound(nTotalRes,2),2)
		nDif := Abs(nTotalRes - nTotFat)
	EndIf
EndIf

If (Abs( nDif ) > 0)
	If lArreFin
		aParcFat[Len(aParcFat)][2] := Round(nUnitFat + nDif + nAdmTax,2)
	Else
		aParcFat[Len(aParcFat)][2] := NoRound(nUnitFat + nDif + nAdmTax,2)
	EndIf

	nTotFat += nDif
EndIf

RestArea(aArea)

Return aParcFat

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ LJ7_TxAdm  ³ Autor ³ Vendas CRM          ³ Data ³ 08/02/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pesquisa o valor do juros conforme a administradora 		  ³±±
±±³          ³ selecionada pelo usuario									  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LJ7_TxAdm(ExpC1,ExpN2,ExpN3)				 				  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametro ³ ExpC1 - Codigo da administradora de cartao   		      ³±±
±±³          ³ ExpN2 - Numero de parcelas								  ³±±
±±³          ³ ExpN3 - Valor pago em CC pelo cliente					  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ aValTax[1] - retorna a tx de juros cobrada pela adm 	      ³±±
±±³          ³ aValTax[2] - retorna o vr do juros 						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701B													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7_TxAdm( cCodAdmin, nParc, nValCC )

Local nTxAdm   	:= 0		//Taxa de Administradora Financeira
Local nTxJur    := 0       	//Taxa de Juros em CC
Local nTxVal	:= 0		//Valor do juros
Local aValTax	:= {0,0,0,0}//Valor e taxa da administradora - variavel para retorno da funcao
Local lPesq		:= .T.		//Variavel para retorno da funcao
Local nJurSemImp:= 0		//Valor do juros Sem Imposto (Localizacoes)
Local nVlImpProp:= 0 		//Valor do Imposto Proporcional (Utilizado para Localizacoes)
Local nTotalVda := 0		//Total da Venda
Local nTotalImp := 0

Default cCodAdmin	:= 0
Default nParc 		:= 0
Default nValCC		:= 0

If IsBlind()
	nTotalVda := IIf( MaFisFound("NF"), MaFisRet( Nil, "NF_TOTAL") , 0 )
Else
	nTotalVda := IIf( MaFisFound("NF"), MaFisRet( Nil, "NF_TOTAL") + IIf(ExistFunc("LjNewCalSol") .And. LjNewCalSol(), Lj7T_DescV(2) ,0) , 0 )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Transforma Variáveis             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nValCC	:= IIf( ValType( nValCC )<> "C", Str( nValCC ), nValCC)
nParc	:= IIf( ValType( nParc ) <> "N", Val( nParc  ), nParc)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Retira todos os pontos do valor  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nValCC := StrTran(nValCC,".","",NIL,NIL)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ No lugar da virgula do decimal coloco ponto  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nValCC := Val(StrTran(nValCC,",",".",NIL,NIL))

If cPaisLoc <> "BRA"
	nTotalImp := Lj7T_ImpsV("1",2)
	//Calcula o valor proporcional do imposto
	If Type("aPgtosSint") != "U" .And. Len(aPgtosSint) == 1 .And. nNCCUsada == 0
		nVlImpProp := nTotalImp
	Else
		nVlImpProp := ( (nValCC * nTotalImp) / nTotalVda )
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Filtra a Administradora para calculo de Juros em Cartao de Credito   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("MEN")
MEN->(DbSetOrder(2)) //MEN_FILIAL+MEN_CODADM+MEN_BANCO
If MEN->(DbSeek(xFilial("MEN") + cCodAdmin))
	While !MEN->(Eof()) .AND. AllTrim(MEN->MEN_CODADM) == AllTrim(cCodAdmin) .AND. lPesq
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Caso o numero de parcelas exista entre o cadastro de juros da administradora entao, ³
		//³ armazena o valor da porcentagem de juros na variavel nTxAdm                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    	If (MEN->MEN_PARINI <= nParc) .AND. (MEN->MEN_PARFIN >= nParc)
    		nTxJur 	:= MEN->MEN_TAXJUR
    		nTxAdm	:=	MEN->MEN_TAXADM
    		nTxVal 	:= A410Arred( nValCC * nTxJur / 100, "L2_VRUNIT" )
    		
    		If cPaisLoc <> "BRA"
    			//Calcula o valor do Juros SEM imposto
	    		nJurSemImp := A410Arred( (nValCC - nVlImpProp) * (nTxJur / 100), "L2_VRUNIT" )
	    	Else
	    		nJurSemImp := nTxVal
	    	EndIf
    		lPesq	:= .F.
    	EndIf
    	MEN->(DbSkip())
	End
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Caso nao tenha juros, retorna zero.              ³
//³ Variaveis ja inicializadas no inicio da funcao   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aValTax[1] := nTxJur
aValTax[2] := nTxVal  //Valor do Juros COM Imposto
aValTax[3] := nTxAdm
aValTax[4] := nJurSemImp //Valor do Juros SEM Imposto, no caso de ( LOCALIZACAO <> Brasil)

Return aValTax

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ LJ7_ParcTx ³ Autor ³ Vendas CRM          ³ Data ³ 08/02/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Tela com simulacao das parcelas a serem alteradas apos a   ³±±
±±³          ³ confirmacao da forma de pagamento						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LJ7_ParcTx(ExpA1,ExpN2,ExpN3,ExpN4,ExpC5)				  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametro ³ ExpA1 - Array das parcelas geradas			   		      ³±±
±±³          ³ ExpA2 - Taxa de juros									  ³±±
±±³          ³ ExpN3 - Total pago em CC									  ³±±
±±³          ³ ExpN4 - Numero de parcelas								  ³±±
±±³          ³ ExpN5 - Id do cadastro de adm financeira					  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ NIL										          	      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701B													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LJ7_ParcTx( aPgtos		, aTaxas, nTotTit, nParcelas,;
							nIdCartao	)
Local aParTmp		:= {}			//Array temporario para recalculo das parcelas com juros
Local nX			:= 0			//Utilizada no FOR
Local nDif			:= 0			//Diferanca das parcelas
Local nVrTotal		:= 0			//Total do cartao sem juros
Local lAutoExB		:= IsBlind()	// Verifica se a rotina sera executada via execauto ou nao

Default aPgtos		:= {}
Default aTaxas		:= {0,0,0,0}
Default nTotTit	:= 0
Default nParcelas	:= 0
Default nIdCartao	:= 0

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se a taxa de juros for maior que zero, entao ³
//³ abre a tela de simulacao das parcelas        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (Len(aTaxas) > 0) .AND. (aTaxas[2] > 0) .AND. !lAutoExB

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criando a tela de simulacao ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DEFINE MSDIALOG oDlgTx FROM 0,0 TO 310,402 PIXEL TITLE STR0183 //"Simulacao de Parcelas com Juros em Cartão de Credito"

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criando o browser     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	oBrowseTx := TWBrowse():New( 5 , 5, 195,  130,,;
			{'','',''},{20,40,40}, oDlgTx, ,,,,;
			{||},,,,,,,.F.,,.T.,,.F.,,, )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Retira todos os pontos do valor  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nTotTit	:= StrTran(nTotTit,".","",NIL,NIL)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ No lugar da virgula do decimal coloco ponto  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nTotTit	:= Val(StrTran(nTotTit,",",".",NIL,NIL))

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Soma o juros com o total da venda  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nVrTotal	:= nTotTit
	nTotTit		:= nTotTit + aTaxas[2]
	nValcJuros	:= A410Arred( nTotTit / Val(nParcelas), "L2_VRUNIT" )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica a diferenca para somar na ultima parcela ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nDif := A410Arred( nTotTit - (nValcJuros * Val(nParcelas)), "L2_VRUNIT" )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criando um array temporario "aParTmp" para mostrar o valor das  ³
	//³ parcelas com juros e suas respectivas datas de vencimento       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nX := 1 to Len(aPgtos)
		If (AllTrim(aPgtos[nX][3]) $ _FORMATEF) .AND. (aPgtos[nX][8] == nIdCartao .OR. Empty(aPgtos[nX][8]))
			aAdd( aParTmp, {	aPgtos[nX][1]	,;
								nValcJuros 		,;
								aPgtos[nx][3] } )
		EndIf
	Next nX

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza a diferenca sempre na ultima parcela			³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (Len(aParTmp) > 0) .AND. (nDif <> 0)
		aParTmp[Len(aParTmp)][2] += nDif
	EndIf

	oBrowseTx:SetArray(aParTmp)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Add valores as colunas do browser        ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	ADD COLUMN TO oBrowseTx HEADER STR0004	OEM DATA { || aParTmp[oBrowseTx:nAt,1]  } ALIGN LEFT  SIZE 40 PIXEL 										//"Data"
	ADD COLUMN TO oBrowseTx HEADER STR0145	OEM DATA { || Transform(aParTmp[oBrowseTx:nAt,2], PesqPict("SL2","L2_VRUNIT")) } ALIGN LEFT  SIZE 40 PIXEL	//"Valor Pago"
	ADD COLUMN TO oBrowseTx HEADER STR0006	OEM DATA { || aParTmp[oBrowseTx:nAt,3]  } ALIGN LEFT  SIZE 40 PIXEL 										//"Forma Pgto."

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criando label com o total da venda sem juros      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 138, 5 SAY STR0184 FONT aFontes[1] PIXEL OF oDlgTx //Total sem Juros:
	@ 138, 65 SAY nVrTotal PICTURE PesqPict("SL2","L2_VRUNIT") COLOR CLR_HBLUE PIXEL OF oDlgTx

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criando label com o total da venda com juros      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	@ 145, 5 SAY STR0182 FONT aFontes[1] PIXEL OF oDlgTx //Total com Juros:
	@ 145, 65 SAY nTotTit PICTURE PesqPict("SL2","L2_VRUNIT") COLOR CLR_HRED PIXEL OF oDlgTx

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Criando o botao OK da tela      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DEFINE SBUTTON FROM 140,173 TYPE 1 ACTION (oDlgTx:End()) ENABLE OF oDlgTx

	ACTIVATE MSDIALOG oDlgTx CENTERED
	oDlgTx := NIL
EndIf

Return (NIL)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ LJ7_UpdPrcTx ³ Autor ³ Vendas CRM          ³ Data ³ 18/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Atualiza as parcelas com o valor final no array apgtos   	³±±
±±³          ³ e atualizando o total da venda							  	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LJ7_UpdPrcTx(ExpA1,ExpN2,ExpN3,ExpN4)					  	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametro ³ ExpA1 - Array das taxas de juros				   		      	³±±
±±³          ³ ExpA2 - Array temporario das parcelas com o juros		  	³±±
±±³          ³ ExpA3 - Array com os dados do cartao						  	³±±
±±³          ³ ExpA4 - Array das taxas de juros							  	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ NIL										          	      	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701B													  	³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LJ7_UpdPrcTx(aTaxJuros, aParTmp, aDadosAdm, aTaxas,;
								 cFormaPg	)

Local nAuxFor		:= 0 	//Utilizada no FOR
Local nValcJuros	:= 0 	//Valor de cada parcela
Local nDif			:= 0 	//Diferenca das parcelas
Local nTotal		:= 0 	//Valor tota venda
Local nContador	:= 0 	//Contador de parcelas
Local nDAdm		:= 0	//Recebe o valor total do cartao

Default aTaxJuros 	:= {}
Default aParTmp		:= {}
Default aDadosAdm		:= {}
Default aTaxas		:= {}
Default cFormaPg	:= ""

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se a taxa de juros for maior que zero     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (Len(aTaxas) > 0) .AND. (aTaxas[1] > 0)

    If Len(aTaxJuros) == 0
		aTaxJuros := {0,0,0,0}
	ElseIf Len(aTaxJuros) == 2
		aTaxJuros := {aTaxJuros[1],aTaxJuros[2],0,0}
	EndIf

	aTaxJuros[1] += aTaxas[1]
	aTaxJuros[2] += aTaxas[2]
	aTaxJuros[3] += aTaxas[3]
	aTaxJuros[4] += aTaxas[4]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Soma valor das parcelas sem juros ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nAuxFor := 1 To Len( aParTmp )
		nTotal += aParTmp[nAuxFor][2]
	Next nAuxFor
	nTotal += aTaxas[2]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Retira todos os pontos do valor  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nDAdm := StrTran(aDadosAdm[1][1],".","",NIL,NIL)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ No lugar da virgula do decimal coloco ponto  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nDAdm := Val(StrTran(nDAdm,",",".",NIL,NIL))

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Total que sera pago em determinado cartão                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nTotTit := nDAdm + aTaxas[2]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Valor de cada parcela      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nValcJuros := A410Arred( nTotTit / Val(aDadosAdm[1][3]), "L2_VRUNIT" )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Diferença que sera somada na ultima parcela  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nDif := A410Arred( nTotTit - (nValcJuros * Val(aDadosAdm[1][3])), "L2_VRUNIT" )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza o array aPgtos para contemplar o valor do juros ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nAuxFor := 1 To Len( aParTmp )
		If (AllTrim(aParTmp[nAuxFor][3]) $ _FORMATEF) .AND.;
		 	(aParTmp[nAuxFor][8] == aDadosAdm[1][7] .OR. Empty(aParTmp[nAuxFor][8])) .AND.;
		 	AllTrim(cFormaPg) == AllTrim(aParTmp[nAuxFor][3]) 	// Forma de pagamento

			aPgtos[nAuxFor][2] 	:= nValcJuros
			nContador 			:= nAuxFor
		EndIf
	Next nAuxFor

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza a diferenca sempre na ultima parcela			³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (Len(aPgtos) > 0) .AND. (nDif <> 0)
		aPgtos[nContador][2] += nDif
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza o total pago em cartao no array ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aDadosAdm[1][1] := nTotTit

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza Total    ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7T_Total( 2, nTotal )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualiza Parcelas ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7T_TotPar( 2, nTotal )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se estiver usando visualiz. sintetica atualiza o array/browse sintetico ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	oPgtos:SetArray( aPgtos )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualizando o apgtossint com o valor a ser pago em CC ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nAuxFor := 1 To Len( aPgtosSint )
		If 	(aPgtosSint[nAuxFor][1] $ _FORMATEF) .AND.;
		 	(aPgtosSint[nAuxFor][4] == aDadosAdm[1][7] .OR. Empty(aPgtosSint[nAuxFor][4])) .AND.;
		 	AllTrim(cFormaPg) == AllTrim(aPgtosSint[nAuxFor][1])

			aPgtosSint[nAuxFor][3] 	:= Transform(nTotTit, PesqPict("SL4","L4_VALOR"))
		EndIf
	Next nAuxFor

	oPgtosSint:SetArray( aPgtosSint )
	oPgtosSint:Refresh()

	oPgtos:Refresh()

EndIf

Return NIL

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7TelaFinºAutor  ³ Vendas Clientes    º Data ³  18/07/06   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Tela com os dados das administradoras de cartoes           º±±
±±º          ³                                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7TelaFin( lControlaVale	, oDlgAdm	 , aDadosAdm	, aFontes	,;
							lUsaTef			, nTamAE_COD , oGetDad		, bActionBt1,;
							bActionBt2		, aHeaderMAV , aColsMAV 	, lBotaoOK	,;
							oBt1			, oBt2 		 , aAdminist 	, lCancela	,;
							aVales	   		, aTaxJuros  , cFormaPg	 )

Local nUsado  	:= 0 	// Variavel que varre a aColsMAV
Local nX 		:= 0	// Variavel do For
Local cTipoAdm	:= Posicione("SAE", 1, xFilial("SAE")+Subs(aAdminist[1],1,TamSX3("AE_COD")[1]),"AE_TIPO")
Local aHeaderMDD	:= {}
Local aColsMDD		:= {}
Local aVP			:= {}
Local lUsaVP		:= SuperGetMV("MV_LJVALEP",,.F.) .AND. AllTrim(cTipoAdm) == "VP" 	// Utiliza Fidelizacao de cliente ??
Local lContBancoCC	:= .F.									// Identifica se ira solicitar o numero do banco para cartao de credito/debito
Local nAdic			:= 0
Local cMvTpRet		:= SuperGetMV("MV_LJCTRET",,"RI|RG|RB|RS")
Local oDesconto 	:= Nil									// Desconto
Local oBanco 		:= Nil
Local lMvLjPdvPa	:= FindFunction("LjxBGetPaf").AND.LjxBGetPaf()[2] //Indica se e PDV
Local oDescBa		:= Nil								//Objeto de controle de desconto
Local aTaxas		:= {0,0,0,0}							//Taxas de juros
Local lMvJurCc		:= SuperGetMV("MV_LJJURCC",NIL,.F.)//Parametro de juros de cartao de credito
Local nVerTel		:= 0								//Tamanho da vertical da tela
Local nTDadosAdm	:= 0
Local cF3Mdd		:= Nil
Local nPosAux 		:= 0

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita as teclas F4, F5, F6, F7³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Default	aVales		:= {}	// Info do vale compra
Default aTaxJuros  	:= {}
Default cFormaPg	:= ""

If lLjDespa
	aDadosF3 := aDadosAdm
EndIf

If lMvJurCc
	nVerTel := 7
Else
	nVerTel := 6
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Exibe campo referente ao banco do cartao de credito/debito³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc == "BOL" .AND. SL4->(FieldPos("L4_BCOCART")) > 0
	lContBancoCC	:= .T.
	nAdic 			:= 1
	aDadosAdm[1][8]	:= Space(TamSX3("L4_BCOCART")[1])
EndIF

If lLjDespa
	nAdic 			+= 1
	aDadosAdm[1][8]	:= Space(TamSX3("A1_COD")[1])
EndIf

LjTeclas( .F., .F., .F., .F. )
DEFINE MSDIALOG oDlgAdm FROM 12, 20 TO If( lControlaVale .OR. lUsaVP , 33 + nAdic, 27 + nAdic ), 60 TITLE STR0065 OF oDlgVA 	//"Financiadora"

@ 00.3 , 01 TO nVerTel + nAdic, 18.9 OF oDlgAdm
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Valor do t¡tulo:³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
@ 01.0, 02.0 SAY STR0066  SIZE 10,1 FONT aFontes[1] OF oDlgAdm  		//"Valor do título:"
@ 01.0, 06.0 SAY aDadosAdm[2][1] VAR aDadosAdm[1][1] SIZE 10,1 RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
//ÚÄÄÄÄÄÄ¿
//³ Data:³
//ÀÄÄÄÄÄÄÙ
@ 02.0, 02.0 SAY STR0106  SIZE 4,1 FONT aFontes[1] OF oDlgAdm 			//"Data:"
@ 02.0, 04.0 SAY aDadosAdm[2][2] VAR aDadosAdm[1][2] SIZE 8,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
//ÚÄÄÄÄÄÄÄ¿
//³ Parc.:³
//ÀÄÄÄÄÄÄÄÙ
@ 02.0, 08.0 SAY STR0107 SIZE 5,1 FONT aFontes[1] OF oDlgAdm 		//"Parcelas:"
@ 02.0, 11.4 SAY aDadosAdm[2][3] VAR aDadosAdm[1][3] SIZE 1,1 RIGHT COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
//ÚÄÄÄÄÄ¿
//³Seq.:³
//ÀÄÄÄÄÄÙ
If cPaisLoc == "BRA"
	If lUsaTef .AND. SuperGetMV("MV_TEFMULT") .AND. !Empty(aDadosAdm[1][7])
		@ 02.0, 14.2 SAY STR0108 SIZE 3,1 FONT aFontes[1] OF oDlgAdm 		//"Seq.:"
		@ 02.0, 16.2 SAY aDadosAdm[2][7] VAR aDadosAdm[1][7] SIZE 1,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
	EndIf
Else
	If SuperGetMV("MV_TEFMULT") .AND. !Empty(aDadosAdm[1][7])
		@ 02.0, 14.2 SAY STR0108 SIZE 3,1 FONT aFontes[1] OF oDlgAdm 		//"Seq.:"
		@ 02.0, 16.2 SAY aDadosAdm[2][7] VAR aDadosAdm[1][7] SIZE 1,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
	EndIf
EndIf

If (Len(aDadosAdm[1]) > 7) .AND. (aDadosAdm[1][8] == "VP")  .AND. lUsaVP
	//ÚÄÄÄÄÄÄÄ¿
	//³Número:³
	//ÀÄÄÄÄÄÄÄÙ
	If AliasIndic("MDD") .AND. SL2->(FieldPos("L2_VALEPRE")) > 0
		aDadosAdm[1][4] := PadR( aDadosAdm[1][4], TamSX3("L2_VALEPRE")[1] )

		@ 03.0, 02.0 SAY STR0069 OF oDlgAdm 								//"Número:"
		@ 37.0, 60.5 MSGET aDadosAdm[2][4] VAR aDadosAdm[1][4] RIGHT F3 "MDD001" VALID LjVldVlPre( NIL, aDadosAdm[1][4], Val(StrTran(StrTran(aDadosAdm[1][1],".",""),",",".")), 2 ) SIZE 62,10 PIXEL OF oDlgAdm
		aDadosAdm[2][4]:cSx1Hlp:="L4_NUMCART"
	EndIf
ElseIf !lUsaTef .OR. ( cPaisLoc <> "BRA" .AND. cFormaPg $ cMvTpRet)
	//ÚÄÄÄÄÄÄÄ¿
	//³Número:³
	//ÀÄÄÄÄÄÄÄÙ
	aDadosAdm[1][4] := IIf( (cPaisLoc <> "BRA" .AND. cFormaPg $ cMvTpRet), Space(TamSX3("FE_NROCERT")[1]), aDadosAdm[1][4] )
	@ 03.0, 02.0 SAY STR0069 OF oDlgAdm 								//"Número:"
	@ 37.0, 60.5 MSGET aDadosAdm[2][4] VAR aDadosAdm[1][4] RIGHT VALID LjVlNrCert( aDadosAdm[1][4], cFormaPg ) SIZE 62,10 PIXEL OF oDlgAdm
	aDadosAdm[2][4]:cSx1Hlp:="L4_NUMCART"
EndIf

//ÚÄÄÄÄÄÄ¿
//³Descon³
//ÀÄÄÄÄÄÄÙ
If  lLjDespa
	@ 03.0, 02.0 SAY STR0179 SIZE 6,1 FONT aFontes[1] OF oDlgAdm  //"Desconto (%):"
	@ 03.0, 07.6 SAY oDesconto VAR aDadosAdm[1][9] SIZE 8,1 COLOR CLR_HRED FONT aFontes[1] OF oDlgAdm
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Administradora:³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
@ 04.0, 02.2 SAY STR0070 OF oDlgAdm 									//"Administradora:"
@ 04.0, 08.7 MSCOMBOBOX aDadosAdm[2][5] VAR aDadosAdm[1][5] ITEMS aAdminist VALID LjVldAdm(@aDadosAdm, @oBanco, @oDescBa) .AND. (aTaxas := IIF(lMvJurCc,LJ7_TxAdm(Substr(aDadosAdm[1][5],1, nTamAE_COD),aDadosAdm[1][3], aDadosAdm[1][1]), {0,0})) SIZE 80,40 OF oDlgAdm
aDadosAdm[2][5]:cSx1Hlp := "L4_ADMINIS"

If Len(aAdmsFinRG) > 0
	nPosAux := aScan( aAdmsFinRG, {|x| AllTrim(x[1])+AllTrim(x[3]) == AllTrim(cFormaPg)+AllTrim(aDadosAdm[1][7]) } )
	If nPosAux > 0
		If ( nPosAux := aScan(aAdminist,aAdmsFinRG[nPosAux][2]) ) > 0
			//Posiciona o ComboBox na Adm. Financeira selecionada anteriormente
			aDadosAdm[2][5]:nAt := nPosAux
			aDadosAdm[2][5]:BWHEN := {|| .F. }
		EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Banco (cartao de credito/debito) - BOLIVIA³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lContBancoCC
	@ 05.0, 02.2 SAY STR0052 OF oDlgAdm //"Banco"
	@ 05.0, 07.8 MSGET aDadosAdm[2][8] VAR aDadosAdm[1][8] RIGHT F3 "Z0" VALID (Empty(aDadosAdm[1][8]) .OR. ExistCpo("SX5","Z0"+aDadosAdm[1][8])) SIZE 5,1 OF oDlgAdm
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Banco para desconto³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If lLjDespa
	oDescBa := TSay():New(05.0, 02.2,{||STR0180},oDlgAdm)
	@ 05.0, 08.7 MSGET oBanco VAR aDadosAdm[1][11] F3 "LOJ001" VALID LJ701VldBc(@aDadosAdm) SIZE 5,1 OF oDlgAdm F3 "LOJ001"
	oBanco:lVisible  	:= .F.
	oDescBa:lVisible 	:= .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Controle do bChange da administradora financeira. Valida se existe controle de   ³
//³ vale-compras para habilitar ou desabilitar os controles ou o action do botao Ok  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aDadosAdm[2][5]:bChange :=	{ || If(LJ7_VldAdm( Substr( aDadosAdm[1][5], 1, nTamAE_COD)),;
											(oBt1:bAction:=bActionBt1, .T.),;
											(oBt1:bAction:=bActionBt2, .F.)) }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Utiliza nas próximas parcelas   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLjDespa
	@ 76.0+(nAdic*12.1), 15.0 CHECKBOX aDadosAdm[2][6] VAR aDadosAdm[1][6] PROMPT STR0046 SIZE 90,7 WHEN (!lUsaVP .And. Len(aAdmsFinRG)==0) PIXEL OF oDlgAdm
Else
	@ 67.0+(nAdic*12.1), 15.0 CHECKBOX aDadosAdm[2][6] VAR aDadosAdm[1][6] PROMPT STR0046 SIZE 90,7 WHEN (!lUsaVP .And. Len(aAdmsFinRG)==0) PIXEL OF oDlgAdm
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Cria o label Tx. Juros Admin.:  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lMvJurCc .AND. (Len(aDadosAdm) > 0)
	aTaxas := LJ7_TxAdm(Substr(aDadosAdm[1][5],1, nTamAE_COD),aDadosAdm[1][3], aDadosAdm[1][1])

	@ 06.0, 02.0 SAY STR0185 FONT aFontes[1] OF oDlgAdm //"Tx. Juros Admin.: "
	@ 06.0, 09.5 SAY aTaxas[1] PICTURE "@E 99.99%" SIZE 3,2 COLOR CLR_HBLUE RIGHT FONT aFontes[1] OF oDlgAdm
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Vale Compra - Se o cliente utiliza campanha de fidelizacao e a                   ³
//³forma de pagamento for VA, o Sistem assume que o pagamento                        ³
//³e vale compra e solicita o numero do vale compra                                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lControlaVale
	aHeaderMAV := {}
	aColsMAV   := {}

	Aadd(aHeaderMAV,{RTrim(RetTitle("MAV_CODIGO")),"MAV_CODIGO","@!",;   //"Codigo"
	15,0,"Lj7PesqVale()",Nil,"C","",,,,,".F.",,,,})

	Aadd(aHeaderMAV,{RTrim(RetTitle("MAV_VALOR")),"MAV_VALOR","@E 9,999,999.99",;   //"VALOR"
	15,0,"",Nil,"N","",,,,,".F.",,,,})

	If MAV->(FieldPos( "MAV_DTVALI" )) > 0
		Aadd(aHeaderMAV,{RTrim(RetTitle("MAV_DTVALI")),"MAV_DTVALI","@!",;   //"VALIDADE"
						 15,0,"",Nil,"D","","V",,,,".F.",,,,})
	EndIf



	nUsado := Len(aHeaderMAV)
	aColsMAV := Array( 1 , (nUsado+1) )
	aColsMAV[1,nUsado+1] := .F.
	For nX := 1 To nUsado
		aColsMAV[1, nX] := CriaVar(aHeaderMAV[nX,2],.T.)
	Next nX

	oGetDad := MsNewGetDados():New(	87+(nAdic*12.1), 08, 140, 150, ;
									GD_INSERT + GD_DELETE + GD_UPDATE,;
									"AllwaysTrue"	,	;
									"AllwaysTrue"	, 	;
									Nil				, 	;
									{"MAV_CODIGO"} 	, 	;
									NIL				, 	;
									999				, 	;
									NIL				,	;
									NIL				,	;
									NIL				,	;
									oDlgAdm			,	;
									aHeaderMAV		,	;
									aColsMAV 			)
	oGetDad:oBrowse:lVisibleControl:= LJ7_VldAdm( Substr( aDadosAdm[1][5], 1, nTamAE_COD ) )
	oGetDad:Refresh()
ElseIf lUsaVP
	If !lMvLjPdvPa
		cF3Mdd := "MDD002"
	EndIf
	If AliasInDic("MDD")
		SX3->( dbSetOrder(2) )
		SX3->( dbSeek( "MDD_CODIGO" ) )
		aHeaderMDD := {}
		SX3->( aAdd( aHeaderMDD,{	X3TITULO()		,;	//01 Titulo
									X3_CAMPO		,;	//02 Campo
									X3_PICTURE		,;	//03 Picture
									X3_TAMANHO		,;	//04 Tamanho
									X3_DECIMAL		,;	//05 Decimal
									If((nModulo <> 23 .AND. lMvLjPdvPa ),"FR271GRVP()","LJ701BGRVP()"),; //06 Valid
									Nil				,;	//07 Usado
									X3_TIPO			,;	//08 Tipo
									cF3Mdd			,;	//09 Arquivo
									X3_CONTEXT		,;	//10 Contexto
									X3_CBOX			,;	//11 CBOX
						  			""				,;	//12 Relaxao
									".T."			,;	//
									" "				,;	//14 Visual
									" "				,;	//15 VldUser
									X3_PICTVAR		}))	//16 PictVar

		SX3->( dbSeek( "MDD_VALOR" ) )
		SX3->( aAdd( aHeaderMDD,{	X3TITULO()		,;	//01 Titulo
									X3_CAMPO		,;	//02 Campo
									X3_PICTURE		,;	//03 Picture
									X3_TAMANHO		,;	//04 Tamanho
									X3_DECIMAL		,;	//05 Decimal
									" "				,;	//06 Valid
									Nil				,;	//07 Usado
									X3_TIPO			,;	//08 Tipo
									cF3Mdd	   		,;	//09 Arquivo
									X3_CONTEXT		,;	//10 Contexto
									X3_CBOX			,;	//11 CBOX
									"0"				,;	//12 Relaxao
									".T."			,;	//
									"V"				,;	//14 Visual
									" "				,;	//15 VldUser
									X3_PICTVAR		}))//16 PictVar

		aColsMDD := {}
		aAdd( aColsMDD, { Space(TamSX3("MDD_CODIGO")[1]), 0, .F. } )

		oValePre := MsNewGetDados():New(	87+(nAdic*12.1), 08, 140, 150, ;
											GD_INSERT + GD_DELETE + GD_UPDATE,;
											"AllwaysTrue"	,;
											"AllwaysTrue"	,;
											Nil				,;
											Nil				,;
											NIL				,;
											99				,;
											NIL				,;
											NIL				,;
											NIL				,;
											oDlgAdm			,;
											aHeaderMDD		,;
											aColsMDD		)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define o bloco de codigo da acao do botao OK quando houver controle  ³
//³ de vale-compras                                                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
bActionBt1 := { || ( lBotaoOk := Lj7CtrVale(oGetDad:aCols), If( lBotaoOk, aVale:=oGetDad:aCols, Nil), If( lBotaoOk, oDlgAdm:End(), Nil) ) }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define o bloco de codigo da acao do botao OK quando nao houver       ³
//³ controle de vale-compras                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
bActionBt2 := { || ( lBotaoOk := .T., 	LJ7_UpdPrcTx(@aTaxJuros, aPgtos, @aDadosAdm, aTaxas,cFormaPg ), oDlgAdm:End())  }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define o bloco de codigo da acao do botao OK quando houver controle  ³
//³ de vale-presente                                                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
bActionBt3 := {|| If( Lj7VldOkVP( oValePre:aCols, Val(StrTran(StrTran(aDadosAdm[1][1],".",""),",",".")) ), ( lBotaoOk := .T., aVP := aClone( oValePre:aCols ), oDlgAdm:End() ), nil ) }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define o botao Ok dependendo do controle de vale-compras             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lControlaVale
	DEFINE SBUTTON oBt1 FROM 145, 088 TYPE 1 ENABLE OF oDlgAdm
	oBt1:bAction := bActionBt1
ElseIf lUsaVP
	DEFINE SBUTTON oBt1 FROM 145, 088 TYPE 1 ENABLE OF oDlgAdm
	oBt1:bAction := bActionBt3
Else
	DEFINE SBUTTON oBt1 FROM 100, 088 TYPE 1 ENABLE OF oDlgAdm
	oBt1:bAction := bActionBt2
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define o botao de cancelamento                                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DEFINE SBUTTON oBt2 FROM If( lControlaVale .OR. lUsaVP , 145, 100 )+(nAdic),121.1 TYPE 2 ACTION (lCancela := .T.,oDlgAdm:End()) ENABLE OF oDlgAdm

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define o botao de visualizacao das parcelas                          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lMvJurCc .AND. (Len(aTaxas) > 0) .AND. (Len(aDadosAdm) > 0)
	oButton := tButton():New(If( lControlaVale .OR. lUsaVP , 145, 100 ) + (nAdic), 8, STR0186, oDlgAdm, {|| If( aTaxas[1] > 0, LJ7_ParcTx(aPgtos, aTaxas, aDadosAdm[1][1], aDadosAdm[1][3], aDadosAdm[1][7]), NIL ) }, 30, 11,,,, .T.) //"Visualizar"
EndIf

ACTIVATE MSDIALOG oDlgAdm CENTERED

If lControlaVale
	aVales := oGetDad:aCols
EndIf

If lUsaVP
	nTDadosAdm := Len(aDadosAdm)
	aEval( aVP, {|x| If( !x[Len(x)], aAdd( aDadosAdm, { x[1], x[2] } ), nil ) } )
	If Len(aDadosAdm) > nTDadosAdm
		aDadosAdm[1][4] := aDadosAdm[Len(aDadosAdm)][1]
	EndIf
EndIf
LjTeclas( .T., .T., .T., .T. )

Return( .T. )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7EmitTerºAutor  ³ Vendas Clientes    º Data ³  04/09/06   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Mostra ou esconde os Nome do emitente nos dados do Cheque  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ void Lj7EmitTer( ExpA1, ExpO1 )                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpL1 -	Array com os dados do cheque                      º±±
±±º			 ³ ExpO1 -  Objeto de dialogo para informar os dados do Chequeº±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7EmitTer(aDadosChq, oDlgChq)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se o cheque de terceiros esta desabilitado³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If aDadosChq[1][12]
	aDadosChq[2][14]:Enable()
Else
	aDadosChq[2][14]:Disable()
EndIf

aDadosChq[2][14]:Refresh()
oDlgChq:Refresh()

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjTelaAltPGºAutor  ³ Vendas Clientes    º Data ³  10/01/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Tela de alteracao da forma de pagamento                     º±±
±±º          ³                                                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpO1 - Objeto pagamento                                     º±±
±±º          ³    2 - Objeto de Tela                                       º±±
±±º          ³    3 - Objeto da data                                       º±±
±±º          ³    4 - Objeto do valor                                      º±±
±±º          ³    5 - Objeto da forma de forma de pagamento                º±±
±±º          ³    6 - Objeto do check de pagamento                         º±±
±±º          ³    7 - Objeto do parcelamento                               º±±
±±º          ³    8 - Objeto do cartao                                     º±±
±±º          ³    9 - Objeto da emissao                                    º±±
±±º          ³   10 - Objeto do pagamento                                  º±±
±±º          ³ExpC1 - Codigo da forma de pagamento                         º±±
±±º          ³ExpL1 - Visualizacao sintetizada                             º±±
±±º          ³ExpC2 - Identificacao do ID do cartao                        º±±
±±º          ³ExpC3 - Forma de pagamento                                   º±±
±±º          ³ExpN1 - Numero de parcelos                                   º±±
±±º          ³ExpA1 - Array das formas de pagamento                        º±±
±±º          ³ExpA2 - Array DO aPgtos				                       º±±
±±º          ³ExpL2 - Aplica para as proximas parcelas                     º±±
±±º          ³ExpD1 - Aplica para as proximas parcelas                     º±±
±±º          ³ExpN1 - Define qual tela utilizar                            º±±
±±º          ³ExpO11- Objeto da moeda                                      º±±
±±º          ³ExpC4 - Variavel de moeda                                    º±±
±±º          ³ExpA3 - Array com as moedas                                  º±±
±±º          ³ExpA4 - Array com as moedas                                  º±±
±±º          ³ExpN2 - Moeda corrente                                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³NIL                                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701B                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LJTELAALTPG(oDlgPgto	, oDlgVA	, oData		, oValor	, ;
						    oForma		, oCheckPag	, oParc		, oCart		, ;
						    oEmissao    , oPgtos	, dData		, nValor	, ;
						    aFormas		, aPgtos	, nLinha	, cCodForma	, ;
						    lVisuSint	, cFormaId	, cForma	, nParc		, ;
						    aFormPgtos	, lCheckPag , lConfirma	, dEmissao	, ;
						    nTela		, oMoeda    , cMoeda 	, aMoeda 	, ;
						    aValores 	, nMoedaParc, lSenha	, lTefPendCS, ;
						    oCheque		, cChequeId	, aTefBKP   )

Local lRet		:= .T.
Local oIDCart
Local cBkpID	:= ""			// Id Antes da abertura da tela para alteração
Local cBkpForm	:= ""			// Forma antes da tela para alteração
Local nX		:= 0			// Contador do FOR
Local lAtuPf	:= (SuperGetMv("MV_LJATUPF",,"N") == "S")
Local nBkpVlr	:= 0
Local lPBMDesc		:= ExistFunc("T_DroPbmDe") .AND. T_DroPbmDe()

Default lSenha		:= .T.		//Variavel utilizada para pedir senha de liberacao para alterar parcelas
Default oCheque		:= nil
Default cChequeId	:= ""
DEFAULT aTefBKP		:= {}		// Array com os TEF Pendentes
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o usuario pode utilizar condicoes negociadas     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If lSenha
	lRet := LjProfile( 9 )
EndIf
// Verifica se a alteracao eh um cartao que ja foi aprovado no TEF
For nX := 1 to Len(aTefBKP)
	If 	cCodForma 	= aTefBKP[nX]:CFORMA	  .AND.;
		cFormaId 	= aTefBKP[nX]:CIDCART

		MsgAlert(STR0199) // O cartão selecionado já foi aprovado e não pode ser alterado.
		lRet := .F.
	EndIf
Next nX

cBkpID 		:= cFormaId //Forma ID
cBkpForm 	:= cCodForma //Codigo da Forma
nBkpVlr	:= nValor		//Valor de saldo

If lRet
	If nTela == 1

		DEFINE MSDIALOG oDlgPgto TITLE STR0045 FROM 0,0 TO 15,41 OF oDlgVA  //"Pagamento"
		@ 0.3,1 TO 7,18.9 OF oDlgPgto

		@ 1,2    SAY STR0004 SIZE 10,1  			//"Data"
		@ 1,7.5  MSGET oData VAR dData RIGHT SIZE 45,08 VALID (dData >= dDatabase)
		oData:cSx1Hlp:="L4_DATA"
		
		//Valida se utilizou o PBM para que nao seja possivel editar a forma de pagamento Convenio ("CO")
		If !lPBMDesc .AND. ExistFunc("LjVldPbm") .And. LjVldPbm() .And. cCodForma $ "CO"
			nValor := 0
		EndIf
		
		@ 2,2    Say STR0005 SIZE 10,1 			//"Valor"
		@ 2,7.5  MSGET oValor VAR nValor	RIGHT SIZE 55,08 PICTURE PesqPict("SL1","L1_VLRTOT") VALID(If (nValor < 0,(MsgStop(STR0096), .F.),.T.)) WHEN nValor > 0 // Valor nao permitido para esse campo.
        oValor:cSx1Hlp:="L4_VALOR"


		@ 3,2    Say STR0006 SIZE 10,1 			//"Forma Pgto"
		@ 3,7.5  MSCOMBOBOX oForma VAR cForma ITEMS aFormas OF oDlgPgto SIZE 75,10 ;
			WHEN (nLinha > 0) VALID LjProfile(39,,,,,.T.)
		oForma:cSx1Hlp:="L4_FORMA"

		If SuperGetMV("MV_TEFMULT") .AND. lVisuSint .AND. ((nLinha == 0 .AND. !(cCodForma $ "CH")) .OR. (nLinha > 0))
			@ 4,2    Say oIDCart VAR STR0104 SIZE 10,1 	//"ID Cartão"
			@ 4,7.5  MSGET oCart VAR cFormaId RIGHT SIZE 15,08 PICTURE PesqPict("SL4","L4_FORMAID") ;
				WHEN  Lj7WhenID(nLinha,cForma,@cFormaId,oCart,oIDCart) VALID Lj7ValidID(cForma, @cFormaId, lTefPendCS,cBkpID,cBkpForm )
			oCart:cSx1Hlp:="L4_FORMAID"
		EndIf

		If cPaisLoc == "ARG" .AND. (SL4->(FieldPos("L4_CHEQID")) > 0) .AND. (cCodForma $ "CH")
			@ 4,2    Say STR0171 SIZE 10,1 	//"ID Cheque"
			@ 4,7.5  MSGET oCheque VAR cChequeId RIGHT SIZE 15,08 PICTURE PesqPict("SL4","L4_CHEQID") ;
				WHEN  Lj7WhenChID(nLinha,cForma,@cChequeId) VALID Lj7ValChID(cForma,@cChequeId)
			oCheque:cSx1Hlp:="L4_CHEQID"
		EndIf

		If lVisuSint
			If nLinha == 0 .AND. ((cCodForma $ _FORMATEF ) .Or. (cCodForma == "FI" .And. lAtuPf))
				@ 5,2    Say STR0040 SIZE 10,1 		//"Parcelas"
				@ 5,7.5  MSGET oParc VAR nParc	RIGHT SIZE 15,08 PICTURE "99" VALID(If (nParc < 1 ,(MsgStop(STR0096), .F.),.T.)) // Valor nao permitido para esse campo
				oParc:cSx1Hlp:=""
			EndIf
		EndIf

		If nLinha > 0 .AND. ;
				nLinha < Len(aPgtos) .AND. ;
				!IsMoney(aFormPgtos[Ascan(aFormPgtos,{|x| AllTrim(Upper(x[2]))==AllTrim(Upper(cForma))})][1])
			@ 80,16  CHECKBOX oCheckPag VAR lCheckPag PROMPT STR0046 SIZE 90,8 OF oDlgPgto //"Utiliza nas próximas parcelas"
			oCheckPag:cSx1Hlp:=""
		EndIf

		DEFINE SBUTTON FROM 100,095 	TYPE 1 ACTION ( If(LjVldPgto(dData,nValor,cForma,nParc,cCodForma,nBkpVlr), (lConfirma := .T., oDlgPgto:End()), Nil) ) ENABLE //Confirmar
		DEFINE SBUTTON FROM 100,124.1 	TYPE 2 ACTION ( oDlgPgto:End(), IIf(lNovRegDesc, LjRetLj7T(),Nil) ) ENABLE	//Cancelar

		ACTIVATE MSDIALOG oDlgPgto CENTERED

	Else
		DEFINE MSDIALOG oDlgPgto TITLE STR0045 FROM 0,0 TO 20,41 OF oDlgVA  //"Pagamento"
		@ 0.3,1 TO 9,18.9 OF oDlgPgto

		@ 1,2    SAY STR0079 SIZE 10,1   //"Emissao"
		@ 1,7.5  MSGET oEmissao VAR dEmissao RIGHT SIZE 45,08 VALID Lj7DtEmis(dEmissao, dData, cForma, oPgtos, @aPgtos)

		@ 2,2    SAY STR0080 SIZE 10,1   //"Vencimento"
		@ 2,7.5  MSGET oData VAR dData RIGHT SIZE 45,08 VALID (IIf(cPaisLoc == "ARG", (dData >= dEmissao), (dData >= dDatabase)))

		@ 3,2    Say STR0005 SIZE 10,1 //"Valor"
		@ 3,7.5  MSGET oValor VAR nValor RIGHT SIZE 55,08 PICTURE PesqPict("SL1","L1_VLRTOT")

		@ 4,2    Say STR0006 SIZE 10,1 //"Forma Pgto"
		@ 4,7.5  MSCOMBOBOX oForma VAR cForma ITEMS aFormas OF oDlgPgto SIZE 75,10

		@ 5,2    Say STR0078 SIZE 10,1  //"Moeda"
		@ 5,7.5  MSCOMBOBOX oMoeda VAR cMoeda ITEMS aMoeda OF oDlgPgto SIZE 75,55 WHEN .F.

		If SuperGetMV("MV_TEFMULT") .AND. lVisuSint .AND. !(cCodForma $ "CH")
			@ 6,2    Say oIDCart VAR STR0104 SIZE 10,1 	//"ID Cartão"
			@ 6,7.5	MSGET oCart VAR cFormaId RIGHT SIZE 15,08 PICTURE PesqPict("SL4","L4_FORMAID") ;
				WHEN  Lj7WhenID(nLinha,cForma,@cFormaId,oCart,oIDCart) VALID Lj7ValidID(cForma, @cFormaId, lTefPendCS,cBkpID,cBkpForm )
			oCart:cSx1Hlp:="L4_FORMAID"
		EndIf

		If cPaisLoc == "ARG" .AND. (cCodForma $ "CH") .AND. (SL4->(FieldPos("L4_CHEQID")) > 0)
			@ 6,2    Say STR0171 SIZE 10,1 	//"ID Cheque"
			@ 6,7.5	MSGET oCheque VAR cChequeId RIGHT SIZE 15,08 PICTURE PesqPict("SL4","L4_CHEQID") ;
				WHEN  Lj7WhenChID(nLinha,cForma,@cChequeId) VALID Lj7ValChID(cForma, @cChequeId)
			oCheque:cSx1Hlp:="L4_CHEQID"
		EndIf

		If cPaisLoc == "ARG" .AND. lVisuSint .AND. (nLinha == 0 .AND. cCodForma $ _FORMATEF )
			@ 7,2    Say STR0040 SIZE 10,1 		//"Parcelas"
			@ 7,7.5  MSGET oParc VAR nParc	RIGHT SIZE 15,08 PICTURE "99" VALID(If (nParc < 1 ,(MsgStop(STR0096), .F.),.T.)) // Valor nao permitido para esse campo
			oParc:cSx1Hlp:=""
		EndIf

	   	//"Conversao"
		If Len(aMoeda) > 1
			@ 47,118 BUTTON STR0081 SIZE 30,13 ACTION (Lj7ConvMoeda(	@cMoeda	, @oMoeda	, @nValor, @oValor, ;			//"Conversao"
			aMoeda	, @aValores , @nMoedaParc)) OF oDlgPgto PIXEL
		EndIf

		@ 105,16  CHECKBOX oCheckPag VAR lCheckPag PROMPT STR0046 SIZE 95,8 OF oDlgPgto //"Utiliza nas próximas parcelas"

		DEFINE SBUTTON FROM 130,095 	TYPE 1 ACTION (If(lLayAway,oDlgPgto:End(),(lConfirma := .T., oDlgPgto:End()))) ENABLE
		DEFINE SBUTTON FROM 130,124.1	TYPE 2 ACTION (oDlgPgto:End()) ENABLE

		ACTIVATE MSDIALOG oDlgPgto CENTERED

	EndIf

EndIf

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ Lj7CalcFrete	 ³ Autor ³ Vendas Clientes  ³ Data ³ 25/09/06 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Calcula o Frete da venda                                   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7CalcFrete()                                             ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ Nenhum                                                     ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ Retorna o valor do frete                                   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ Sigaloja - Venda Assistida                                 ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7CalcFrete( lJob , lICMSSolid, nIcmSolDif, lAtuTotal )

Local nVlrFSD 	:= 0	// Valor do frete + seguro + despesa
Local nIcmSolOri:= 0		// valor do ICMS Solidario SEM frete
Local nIcmSolAtu:= 0		// valor do ICMS Solidario COM frete
Local lECommerce:= SuperGetMV("MV_LJECOMM",,.F.) .AND. ( SL1->((ColumnPos("L1_ECFLAG") > 0) .AND. (L1_ECFLAG == "1")) )  .AND. !lJob //PEDIDO E-COMMERCE
Local lMvLjIPEn	:= SuperGetMV("MV_LJIPENP",, .F.)
Local nVlIPIAnt	:= 0 //Valor do IPI Anterior
Local nVlIPIAtu	:= 0 //Valor do IPI Atual
Local nFrete	:= 0 //Valor somente do campo frete
Local nDespesa	:= 0 //Valor somente do campo despesa
Local nSeguro	:= 0 //Valor somente do campo seguro
Local lECCia	:= SuperGetMV("MV_LJECOMO",,.F.) //E-commerce CiaShop habilitado?

DEFAULT lJob 		:= .F.
DEFAULT lICMSSolid	:= .F.	// Possui calculo de ICMS Solidario
DEFAULT nIcmSolDif	:= 0	// diferenca entre ICMS Solidario com e sem frete
DEFAULT lAtuTotal   := .F. //TOTAL ATUALIZADO

/* nModulo == 23: FrontLoja, quando esta função é chamada da Função Lj7CalcPgt onde
não existe a variável lJob e se for Front deve-se por .T. a esta variável*/
lJob := IIf(lJob,lJob,IIf(nModulo == 23,.T.,.F.))

If lJob
	// Mesmo que o campo L1_TPFRET tenha sido informado com "0" ou "S" o valor informado de frete sera somado ao total da venda, mesmo comportamento feito no Faturamento.
	nFrete		:= SL1->L1_FRETE	
	// Independente do Tipo de Frete, (0-Sem Frete / 1 - CIF / 2-FOB) - ) o mesmo pode preencher os campos SL1->L1_DESPESA e SL1->L1_SEGURO
	nDespesa 	:= SL1->L1_DESPESA
	nSeguro		:= SL1->L1_SEGURO	
Else
	// Mesmo que o campo L1_TPFRET tenha sido informado com "0" ou "S" o valor informado de frete sera somado ao total da venda, mesmo comportamento feito no Faturamento.
	nFrete		:= M->LQ_FRETE
	// Independente do Tipo de Frete, (0-Sem Frete / 1 - CIF / 2-FOB) - ) o mesmo pode preencher os campos M->LQ_DESPESA e M->LQ_SEGURO	
	nDespesa 	:= M->LQ_DESPESA
	nSeguro		:= M->LQ_SEGURO	
EndIf

nVlrFSD := nFrete + nDespesa + nSeguro

//Trata item com Substituicao Tributaria e calculo de despesas
If !lJob .AND. nVlrFSD <> 0 .AND. MaFisFound("NF")
	If lICMSSolid
	    If lECommerce .AND. lMvLjIPEn .AND. !lECCia
	    	nVlIPIAnt := Lj7GetIPEC()
	    EndIf
		//obtem o valor do ICMS solidario retido, sem o valor do Frete na BC
		nIcmSolOri := Lj7IcmsSol()
	EndIf
	
	//aplica o valor da frete
	MafisAlt("NF_FRETE", nFrete)	
	//aplica o valor da despesa
	MafisAlt("NF_DESPESA", nDespesa)	
	//aplica o valor da seguro
	MafisAlt("NF_SEGURO", nSeguro)
	
	If lICMSSolid
		//obtem o valor do ICMS Solidario com o valor do frete na BC
		nIcmSolAtu := Lj7IcmsSol()
		//se os valores forem iguais, mantemos o valor, caso contrario, obtemos a diferenca
		nIcmSolDif := IIf( nIcmSolAtu == nIcmSolOri, nIcmSolAtu, nIcmSolAtu - nIcmSolOri )
	
		//Se houve diferença no valor do IPI, então volta para o valor anterior (e-commerce)
		If lECommerce .AND. lMvLjIPEn .AND. !lECCia
	    	nVlIPIAtu := MaFisRet(, "NF_VALIPI")
	 		If nVlIPIAtu <> nVlIPIAnt
	 			MaFisAlt("NF_VALIPI", nVlIPIAnt)
	 		EndIf
	    EndIf
	
	    //impede a alteração do total qdo o ICMS_Solidario = 0 pois se na finalização de orçamento tiver
	    //frete e acrescimo na condição ele retorna ao valor bruto e depois acaba dando um troco
		If nIcmSolAtu > 0 .OR. nIcmSolOri > 0
			Lj7T_Total( 2, MafisRet(,"NF_TOTAL"))
			lAtuTotal := .T.			
		EndIf
	EndIf
EndIf

Return nVlrFSD

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ Lj7lAtuCond	 ³ Autor ³ Vendas Clientes  ³ Data ³ 15/08/07 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Atualiza a variavel lAtuCond (tipo STATIC) para o usuario  ³±±
±±³          ³ possa adicionar/alterar itens no mesmo orcamento mesmo que ³±±
±±³          ³ a opcao "Alterar Parcelas" (no perfil do caixa) esteja     ³±±
±±³          ³ bloqueada. (BOPS 129656)                                   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpL1 - Conteudo que ira' atualizar a variavel lAtuCond    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ Nenhum					                                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ Sigaloja - Venda Assistida                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Chamada   ³ LOJA701C.prw - funcao LJ7GRavacao()                        ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7lAtuCond(lConteudo)

If ValType(lConteudo) == "L"
	lAtuCond := lConteudo
EndIf

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7SaldoBFºAutor  ³ Vendas Clientes    º Data ³  10/10/2007 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao que faz a validacao do lote digitado nos detalhes   º±±
±±º          ³ da venda Assistida.                                        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpC1 - Armazem do produto(opcional)                       º±±
±±º          ³ ExpC2 - Lote do produto(opcional)                          º±±
±±º          ³ ExpC3 - Sublote do produto(opcional)                       º±±
±±º          ³ ExpN4 - Quantidade solicitada para o produto(opcional)     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7SaldoBF(lValidCpo)

Local aArea			:= {} 		//Salva área atual
Local lRet		    := .T.		//Retorno da funcao, liberando ou nao o campo para edicao
Local nPosProd		:= 0 		//Guarda posicao do campo LR_PRODUTO para procura no aColsDet
Local nPosQtde	  	:= 0  		//Guarda posicao do campo LR_QUANT para procura no aCols
Local nPorLoc	    := 0 		//Guarda posicao do campo LR_LOCALIZ para procura no aColsDet
Local nPosSer	    := 0 		//Guarda posicao do campo LR_NSERIE para procura no aColsDet
Local nCount		:= 0		//Variável de controle For Next
Local nQuant		:= 0		//Quantidade do Produto
Local nTamNumSerie	:= 0		//Tamanho do campo Serie do endereco
Local cLocal		:= ""		//Armazem (Local) em que o produto foi vendido
Local cLocaEnd		:= ""		//Endereço selecionado
Local cProduto		:= ""  		//Carrega o codigo do produto do aCols
Local cSerSBF		:= ""		//Serie do endereco
Local lAutoExB 		:= IsBlind()														// Verifica se a rotina sera executada via execauto ou nao
Local lWmsNew		:= SuperGetMv("MV_WMSNEW",.F.,.F.)									// Parâmetro novo WMS

DEFAULT lValidCpo := .F.

If !lWmsNew .AND. Len(aColsDet) >= n //Protecao para realizar procedimento apenas quando possui o item no aColsDet

   	aArea			:= GetArea()
	nPosProd		:= Ascan(aHeader,	{|x| Alltrim(Upper(x[2])) == "LR_PRODUTO"})
	nPosQtde  		:= Ascan(aHeader,   {|x| Alltrim(Upper(x[2])) == "LR_QUANT"})
	nPorLoc	    	:= Ascan(aHeaderDet,{|x| Alltrim(Upper(x[2])) == "LR_LOCALIZ"})
	nPosSer	    	:= Ascan(aHeaderDet,{|x| Alltrim(Upper(x[2])) == "LR_NSERIE"})
	nTamNumSerie	:= TamSX3("BF_NUMSERI")[1]
	cSerSBF			:= Space(nTamNumSerie)


	cLocal			:= M->LR_LOCAL
	
	If lValidCpo 
		cLocaEnd	:=aColsDet[n,nPorLoc]
	Else 
		cLocaEnd	:= M->LR_LOCALIZ
	EndIf 

   	cProduto := aCols[n][nPosProd]

	M->LR_NSERIE		:= LjVerSeri(@cSerSBF,cLocal,cLocaEnd,cProduto)
	cSerSBF				:= PADR(M->LR_NSERIE, nTamNumSerie)

    If Empty(aColsDet[n,nPorLoc]) //Se o produto estiver reservado não verifica o saldo do endereço
    	If Localiza(cProduto) // Valida se o produto possui as configurações para trabalhar com Localização Física
    		For nCount := 1 to Len(aCols)
    			If !aCols[nCount][(len(aHeader)+1)] .AND. (cProduto == aCols[nCount][nPosProd])
    				If (nCount == n)// Se for a mesma linha, não tenho gravado o Endereço no AcolsDet
    					If lValidCpo
    						nQuant += M->LR_QUANT
    					Else
    						nQuant += aCols[nCount][nPosQtde]
    					EndIF
    			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
    			//³ Não é a linha atual, só trato os endereços iguais e se sao das mesmas series ³
    			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    				ElseIf (aColsDet[nCount][nPorLoc] ==  cLocaEnd)  .AND. ( aColsDet[nCount][nPosSer] == cSerSBF )
    					nQuant += aCols[nCount][nPosQtde]
    				EndIf
    				IF !Empty(cLocaEnd) .AND. nQuant > SaldoSBF(cLocal,cLocaEnd,cProduto,cSerSBF,NIL,NIL,.F.,NIL) // Função SaldoSBF retorna a quantidade disponível no endereço
    					lRet := .F.
   						Exit
    				EndIf
    			EndIf
    		Next nCount
    	EndIf
    
    	If !lRet
    		If !lAutoExB
    			Aviso(STR0148,STR0157,{STR0003},2)	// "A quantidade disponível neste Endereço não é suficiente para suprir a quantidade informada."
    		Else
    			ConOut(STR0157)
    		EndIf
    	EndIf
    	RestArea(aArea)
	EndIf
EndIf

Return lRet
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjVerSeri ºAutor  ³Venda Clientes      º Data ³  03/05/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se no determinado endereco possui diversas se'ries º±±
±±º          ³para montar uma tela de escolha, existindo apenas um        º±±
±±º          ³faz o preenchimento do campo se'rie automata'co.            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpC1 - Serie do produto                                   º±±
±±º          ³ ExpC2 - Armazem (Local) em que o produto foi vendido       º±±
±±º          ³ ExpC3 - Endereço selecionado		                          º±±
±±º          ³ ExpN4 - Produto Selecionado                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nulo                                                       º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjVerSeri(cSerSBF,cLocal,cLocaEnd,cProduto)

Local aSerSBF   := {}			 //Array com as Series
Local oDlgSerie                  //Objeto Tela para selecionar a serie caso tenha mais de uma
Local oQualSer                   //Objeto List para listar as series
Local nVarQ     := 0             //Variavel que armazena o item do listbox

Default cSerSBF 	:=""
Default cLocal  	:=""
Default cLocaEnd	:=""
Default cProduto	:=""

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Loop que carrega as series existentes para o determinado endereco³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DbSelectArea("SBF")
DbSetOrder(1)      //BF_LOCALIZ + BF_PRODUTO + BF_NUMSERIE + BF_LOTECIL + BF_NUMLOTE
If DbSeek(xFilial("SBF") + cLocal + cLocaEnd + cProduto)
	While !EOF() .AND. ( xFilial("SBF") + cLocal + cLocaEnd + cProduto == ;
		SBF->BF_FILIAL + SBF->BF_LOCAL + SBF->BF_LOCALIZ + SBF->BF_PRODUTO )
		Aadd(aSerSBF,{Alltrim(SBF->BF_NUMSERI),Alltrim(SBF->BF_LOCALIZ)})
		DbSkip()
		Loop
	End
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Caso a quantidade de series para esse endereco ³
	//³seja maior que 1 monta a tela com os mesmos    ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Len(aSerSBF) > 1
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Series/Endereço     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DEFINE MSDIALOG oDlgSerie TITLE STR0159 From 10,30 To 19.7,68;		// "Séries do Endereço"
	   	OF GetWndDefault()

	 	@ .5,.80 LISTBOX oQualSer VAR nVarQ Fields HEADER STR0160,STR0161 SIZE 130,42; // "Serie"  / "Endereço"
	 	ON DBLCLICK (oQualSer:Refresh(),cSerSBF :=aSerSBF[oQualSer:nAT,1],oDlgSerie:End()) NOSCROLL

		oQualSer:SetArray(aSerSBF)
	 	oQualSer:bLine := { || {aSerSBF[oQualSer:nAT,1],aSerSBF[oQualSer:nAT,2]}}

	 	DEFINE SBUTTON FROM 51,078 TYPE 1 ACTION (cSerSBF :=aSerSBF[oQualSer:nAT,1],oDlgSerie:End())ENABLE OF oDlgSerie

		DEFINE SBUTTON FROM 51,107 TYPE 2 ACTION (oDlgSerie:End()) ENABLE OF oDlgSerie

		ACTIVATE MSDIALOG oDlgSerie CENTERED
	Else
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Caso tenha  apenas uma serie para o endereco  ³
		//³faz o preenchimento automatico do campo serie ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Len(aSerSBF) == 1
			cSerSBF := aSerSBF[1][1]
		EndIf
	EndIf
	cSerSBF := Padr(cSerSBF,TamSx3("BF_NUMSERI")[1]," ") 	
EndIf

Return cSerSBF

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjZeracCondSE4  ºAutor  ³Venda Clientes      º Data ³  12/06/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Função que zera a variavel statica cCondSE4						º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 																	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nulo                                                      		º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±ºUso       ³ SIGALOJA                                                  		º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjZeracCondSE4()

If ValType(cCondSE4) <> "U"
	cCondSE4 := ""
EndIf

//Limpa a variavel static cCondAntX
If ValType(cCondAntX) <> "U"
	cCondAntX := Space(TamSx3("LQ_CONDPG")[1])
EndIf

Return NIL

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7VldOkVPºAutor  ³ Vendas Clientes    º Data ³  29/03/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida o valor dos vales informados                        º±±
±±ºaCols     ³ Acols com os itens do vale presente                        º±±
±±ºnValor    ³ Valor da Venda , não do vale presente                      º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ FRTA271G                                                   º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function Lj7VldOkVP( aCols, nValor )
Local lRet		:= .T.
Local nSoma 	:= 0
Local lAutoExB	:= IsBlind()	// Verifica se a rotina sera executada via execauto ou nao
Local lLj7094	:= ExistBlock("LJ7094")
Local nMvLjPeVp := SuperGetMV("MV_LJPEVP",,0) //Parametro que define se sempre executa ou nao o PE LJ7094

aEval( aCols, {|x| nSoma += If( !x[Len(x)], x[2], 0 ) } )

If nSoma > 0
	//³Ponto de entrada para validar se possibilita ou nao venda de
	// produto com valor menor que o valor do VP. So aciona PE se
	// o valor da venda for menor que o VP ou se o parametro MV_LJPEVP == 1.
	// Incluimos esse parametro pois surgiu a necessidade em um cliente de exexutar o PE independentemente de valor,
	// a maneira que tera um menor impacto devido ao legado foi de criar um parametro desligado para nao alterar o padrao
	// e, se ligar o parametro sempre ira executar o PE independentemente se a venda eh menor que o VP ou vice-versa.
	If lLj7094 .AND. (nValor < nSoma .OR. nMvLjPeVp == 1)
		lRet := ExecBlock("LJ7094",.F.,.F.,{aCols,nValor,nSoma})
		If ValType( lRet ) <> "L"
			lRet := .F.
		EndIf
	EndIf

	If !lLj7094

		If nSoma <> nValor
			lRet := .F.
			If !lAutoExB
				Aviso(STR0001, STR0165+Alltrim(Transform(nSoma, "@E 999,999.99"))+STR0166+;//"Atenção"#"O valor dos vales presentes informados ("#") é diferente "
							STR0167+Alltrim(Transform(nValor,"@E 999,999.99"))+")."+Chr(13)+;//"do valor informado na forma de pagamento ("
							STR0168, {STR0003} )  //"Corrija as informações antes de prosseguir." # "Ok"
			Else
				ConOut(	STR0165+Alltrim(Transform(nSoma, "@E 999,999.99"))+STR0166+;//"Atenção"#"O valor dos vales presentes informados ("#") é diferente "
						STR0167+Alltrim(Transform(nValor,"@E 999,999.99"))+")."+Chr(13)+;//"do valor informado na forma de pagamento ("
						STR0168)
			EndIf
		EndIf
	EndIf
Else
	Aviso(STR0001,STR0213,{STR0003}) //"Não foi informado o código do vale presente!"
	lRet := .F.
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ701BGRVPºAutor  ³ Vendas Clientes    º Data ³  29/03/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida o codigo do vale presente digitado                  º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ701BGRVP()
Local oSvc						// WebService
Local lRet		:= .T.			// Variavel de retorno
Local cMsg		:= ""			// Mensagem de erro
Local nFor		:= 0			// Variavel de laco
Local lAutoExB	:= IsBlind()	// Verifica se a rotina sera executada via execauto ou nao

// Verifica duplicidade de codigos
For nFor := 1 to Len( aCols )
	If nFor <> n .AND. aCols[nFor][1] == &(ReadVar())
		cMsg := STR0169 //"Vale presente já informado."
		lRet := .F.
	EndIf
Next nFor

If lRet
	cMsg := LjVldVP( "", &(ReadVar()), 0, 2 )

	If Empty( cMsg )
		GDFieldPut( "MDD_VALOR", Posicione("MDD",1,xFilial("MDD")+&(ReadVar()), "MDD_VALOR") )
	EndIf
EndIf

If !Empty( cMsg )
	If !lAutoExB
		Aviso( STR0001, cMsg, {STR0003} )  //"Atenção"#"Ok"
	Else
		ConOut(cMsg)
	EndIf
EndIf

Return Empty( cMsg )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7AltCF  ºAutor  ³Vendas Clientes     º Data ³  15/04/2009 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Altera a TES e o CFOP no ListBox de acordo com TES informadaº±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7AltCF()
Local lRet 			:= .F.			// Retorno da funcao
Local nPosTES		:= 0			// Posicao da TES
Local nPosCF		:= 0			// Posicao do Cod. Fiscal
Local aAreaAnt 		:= GetArea()
Local aDadosCfo     	:= {}
Local lCAT83 	:= SLR->(FieldPos("LR_CODLAN")) > 0 .AND. SF4->(FieldPos("F4_CODLAN")) > 0.AND. FindFunction("FISA023").AND. SuperGetMV("MV_CAT8309",,.F.) // Verifica CAT/83
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inicializa as variaveis                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

nPosTES		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})
nPosCF		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"})
nPosCodLan	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CODLAN"})

dbSelectArea('SF4')
dbSetOrder(1)
dbSeek(xFilial('SF4')+M->LR_TES)

If M->LR_TES <> aColsDet[n][nPosTes]
	Alert(STR0214)//"A TES foi alterada porem a alteração do CFOP não sera exibida em tela, a alteração sera atualizada ao confirmar no botão OK."
EndIf

If nPosTES > 0 .AND. nPosCf > 0
	aColsDet[n][nPosTes]	:= SF4->F4_CODIGO

	If cPaisLoc=="BRA" .AND. Left(aColsDet[n][nPosCF],4) == "6405"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Atualiza CFO de devido a nao correspondencia do CFO estadual  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		aColsDet[n][nPosCF] := "6404"+SubStr(aColsDet[n][nPosCF],5,Len(aColsDet[n][nPosCF])-4)
	Else
		If MaFisFound("IT",n)
			aColsDet[n][nPosCF]	:= MaFisRet(n,"IT_CF")
		Else
			aColsDet[n][nPosCF]	:= SF4->F4_CF
		EndIf
	EndIf

	If lCAT83 .AND. nPosCodLan > 0 .AND. !lFtvdVer12
		aColsDet[n][nPosCodLan]		:= SF4->F4_CODLAN
		M->LR_CODLAN				:= SF4->F4_CODLAN
	EndIf

	If Type("aDadList") == "A" //Variaveis private criadas apeans quando clicado no botão detalhes do venda assistida.
		aDadList[1][3] := aColsDet[n][nPosTes]
		aDadList[1][4] := aColsDet[n][nPosCF]
		oListDetIt:Refresh()
	EndIf
	lRet	:= .T.
EndIf

RestArea(aAreaAnt)

Return (lRet)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7AltTes ºAutor  ³Vendas CRM          º Data ³  07/11/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Altera a TES do produto na linha atual                      º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - TES atribuida ao produto                            º±±
±±º          ³ExpL2 - Controla se existe TEF Pendente da CLISITEF         º±±
±±º          ³ExpA3 - Guarda a transacao TEF Pendente da CLISITEF         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7AltTes(cNovaTes, lTefPendCS, aTefBKPCS)

Local aArea			:= GetArea()																	// Salva o posicionamento atual
Local nVlrItem		:= 0 																			// Variavel utilizada para recalculo do valor da venda no caso de alteracao do TES
Local nVlrTotal		:= 0 																			// Variavel utilizada para recalculo do valor da venda no caso de alteracao do TES
Local nPosVlItem    := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]   	// Posicao do Valor Total do Item

Local nPosProd  		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]   	// Posicao do Produto

Local nPQuant  	    := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]   		// Posicao da Quantidade
Local nPDesc     		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]   		// Posicao do  Desconto
Local nPValDesc  		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]   		// Posicao do  Desconto
Local nPPrcTab  		:= aPosCpoDet[Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})][2] // Posicao do Preço de Tabela
Local nPValFrete  	:= aPosCpoDet[Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALFRE"})][2] // Posicao do Valor do Frete
Local nPValSeg  		:= aPosCpoDet[Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_SEGURO"})][2] // Posicao do Valor do Seguro
Local nPValDes  		:= aPosCpoDet[Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESPESA"})][2]// Posicao do Valor da Despesa
Local nAliq	   		:= 0
Local nValIPI 			:= 0
Local nBasIpiUni    	:= 0
Local nQuant
Local nPrcTab
Local nDesc
Local nValDesc
Local nValFrete
Local nValSeg
Local nValDes
Local cTipoCalc   	:= SuperGetMv( "MV_IPIBRUT" )													//Captura o parametro MV_IPIBRUT
Local nTamL2_PRC    	:= TamSX3( "L2_PRCTAB" )[2]														// Tamanho do campo L2_PRCTAB
Local nTamL2_VAL  	:= TamSX3( "L2_VALIPI" )[2] 													// Tamanho do campo L2_VALIPI
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida


If Type("nDecimais")=="U" .AND. lFtvdVer12
   nDecimais  := 2
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Armazena o valor do item antes de alterar o TES              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nVlrItem := If( MaFisFound("IT",n), MaFisRet( n, "IT_TOTAL" ), aCols[n][nPosVlItem] )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama a funcao fiscal para alterar o TES e altera o CFOP     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
MaFisAlt("IT_TES", cNovaTes, n)
aColsDet[n][aScan(aHeaderDet,{ |ExpA1| AllTrim( ExpA1[2] ) == "LR_CF" })] := MaFisRet(n, "IT_CF")

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Recalcula o valor dos itens                                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nVlrTotal := LJ7T_Subtotal(2) - nVlrItem + If( MaFisFound("IT",n), MaFisRet( n, "IT_TOTAL" ), aCols[n][nPosVlItem] )
Lj7T_Subtotal	( 2, nVlrTotal )
Lj7T_Total		( 2, LJ7T_SubTotal(2) - Lj7T_DescV(2) )
Lj7ZeraPgtos( @lTefPendCS, @aTefBKPCS )

RestArea(aArea)

Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7CORRIPIºAutor  ³Microsiga           º Data ³  10/26/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Indica se pegara valor da mercadoria da MATXFIS ou         º±±
±±º          ³ do atotais                                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ AP                                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7CORRIPI()
Local nX			:= 0
Local lRet			:= .F.
Local nPosValIpi	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALIPI" })
Local lVassConc		:= LjVassConc()				//Indica se o cliente utiliza a Vda Assistida Concomitante

If !lVassConc .AND. ((Lj7T_DescV(2) > 0) .OR. (aAcrescimo[1] > 0)) .AND. nPosValIpi > 0
	For nX := 1 To Len(aColsDet)
		If ( (aColsDet[nX][nPosValIpi] > 0) .AND. (!aColsDet[nX][Len(aColsDet[nX])]) )
			lRet	:= .T.
			Exit
		EndIf
	Next nX
EndIf

Return lRet



/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7CondNegºAutor  ³ Vendas Clientes    º Data ³  17/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Chamada do botao de condicao negociada                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpO1 - Painel da condicao negociada(objeto)                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7MultNeg(oPanCondNeg)

Local nVlrAux 		:= 0	// Valor auxiliar
Local nVlrParcelas	:= 0	// Valor Parcela
Local oMultNegoc 	:= Nil	// Multi negociação
Local nFor 			:= 0	// Contador
Local aBkPgtos		:= aPgtos	// Backup do pagaments
Local nDescMn       := 0    // Desconto Multinegociação.
Local lVerEmpres    := Lj950Acres(SM0->M0_CGC) // Verifica as filiais que trabalham com acréscimo separado
Local nxValEnt 		:= 0          																// Valor de Entrada Multinegociação
Local nxValTot 		:= nVlrAux                                                                  // Valor total Multinegociação
Local nxQtdParc 	:= 0                                                                        // Quantidade de parcelas Multinegociação
Local nxValParc		:= 0                                                                        // Valor das Parcelas Multinegociação
Local nxDifParc 	:= 0
Local lMvLjPdvPa	:= FindFunction("LjxBGetPaf").AND.LjxBGetPaf()[2] 							//Indica se e PDV
Local lRetaPaf		:= LjNfPafEcf(SM0->M0_CGC) .And. !lMvljpdvpa 								// Sinaliza Retaguarda PAF-ECF
Local dDtVencSE1	:= Ctod(Space(08))					// Guarda as Datas das Parcelas de vencimentos
Local cDiaVen		:= ""									// Variavel para fixar o dia da primeira parcela e  replicar para as demais
Local lScreen		:= If(Type("_lScreen") == "U", .T.,_lScreen)  					// Verifica se exibe as mensagens na tela ou com conout
Local cAdm			:= ""
Local lAchouAdm		:= .F.
Local lCpoFixSAE	:= SAE->(FieldPos("AE_FIXADIA")) > 0
Local aAreaSAE		:= SAE->(GetArea())
Local lFixaDia		:= .F.															// Fixa dias para multinegociaçao
Local nVlrPago		:= 0
Local nX			:= 0
Local nFreDesSeg	:= M->LQ_FRETE + M->LQ_SEGURO + M->LQ_DESPESA

Default oPanCondNeg	:= Nil

nVlrPago := 0
For nX := 1 to Len(aPgtos)
	nVlrPago += aPgtos[nX][2]
Next nX
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se nao existirem informacoes na aPgtos permitir abertura da tela de multinegociação³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nVlrPago == 0
	nVlrAux	:= Lj7T_Total(2) - nNCCUsada
	
	oMultNegoc := LJCMultNeg():New()
	oMultNegoc:GetMultNeg()
	oMultNegoc:SetValor(nVlrAux)
	oMultNegoc:SetValNCC(nNCCUsada)
	
	aPgtos := {}
	
	If oMultNegoc:oDadosCab:Count() > 0
	    aRetPgto := Lj76TelNeg(@oMultNegoc)
	
	    nxValEnt  := oMultNegoc:GetVEntrad()
	    If Len(aRetPgto) > 0
	
	        dDtVencSE1 := LQ_EMISSAO	// Inicializa variavel com a Data de Emissao
			// ira procurar pela adm financeira para verificar se ha configuracao para
			// fixar a data de vencimento e para nao gerar erro na utlizacao da funcao
			// LJCalcVenc, que necessita da adm estar posicionada
			cAdm	:= If(len(aRetPgto[1])>=9,aRetPgto[1][9],"X")  // ADM financeira utilizada na multinegociacao, realizada em Loja764 function Lj764Conf
			If !Empty(cAdm)
				dbSelectArea("SAE")
				SAE->(dbSetOrder(1))
				If 	SAE->(dbSeek(xFilial("SAE")+AllTrim(cAdm)))
					lAchouAdm := .T.
					If lCpoFixSAE
						If SAE->AE_FIXADIA == "2"		// 1=Nao; 2=Sim
							lFixaDia	:= .T.
						EndIf
					EndIf
				EndIf
			EndIf
				
			aSort( aRetPgto, , , { |x,y| x[8] + Dtos(x[7]) + x[3] < y[8] + Dtos(y[7]) + y[3] } ) // Data + Id Cartao + Forma Pgto
	
	        For nFor := 1 to Len(aRetPgto)
	
	            // Calculo da Data Fixa ficou no LOJA764 pois la deve-se apresentar a tela com as datas das parcelas.
	
	            dDtVencSE1 := aRetPgto[nFor][1]
	
	            aAdd( aPgtos, {	dDtVencSE1,;
	                            aRetPgto[nFor][2],;
	                            aRetPgto[nFor][3],;
	                            aRetPgto[nFor][4],;
	                            NIL,;
	                            If(cPaisLoc<>"BRA",aRetPgto[nFor][_MOEDA],NIL),;
	                            If(cPaisLoc<>"BRA",aRetPgto[nFor][_EMISSAO],NIL),;
	                            If(!Empty(aRetPgto[nFor][8]),aRetPgto[nFor][8],Space(01)) ,;
	                            aRetPgto[nFor][5],;
	                            0 ,;
	                            aRetPgto[nFor][9] } )
	
	            nVlrParcelas += aRetPgto[nFor][2]
	
	        Next nFor
			
			If lVerEmpres .OR. (SuperGetMV("MV_LJICMJR",,.F.) .AND. cPaisLoc == "BRA")
	            nVlrParcelas := 0
	            nxValEnt 	:= 0
		        nxValTot 	:= nVlrAux
		        nxQtdParc 	:= 0
			    nxValParc	:= 0
	            For nFor := 1 to Len(aPgtos)
	                nVlrParcelas += aPgtos[nFor][2]
	            Next nFor
	        Endif

	        If lVisuSint
	            aPgtosSint := Lj7MontPgt(aPgtos)
	            oPgtosSint:SetArray( aPgtosSint )
	            oPgtosSint:Refresh()
	        EndIf
	
	        oPgtos:SetArray( aPgtos )
	        oPgtos:Refresh()
	
	        Lj7T_Total( 2, If(nVlrParcelas>nVlrAux,nVlrParcelas,nVlrAux) + nNCCUsada )
	
	        aAcrescimo[1] := ( nNCCUsada + nVlrParcelas - Lj7T_SubTotal(2)) + If(aDesconto[1]==1,aDesconto[3],0) - nFreDesSeg // Valor do acrescimo
			
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Caso tenha dado um desconto sobre o acrescimo³
			//³significa que esse acrescimo nao existe mais.³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aAcrescimo[1] < 0
				nDescMn := aAcrescimo[1]  // Atribui o Valor do Acrescimo Negativo - Desconto
				nDescMn := nDescMn*(-1)   // Modifica o valor (-)Negativo para (+)Positivo para constar como Desconto no final
				aAcrescimo[1] := 0 		   // Zera Variavel.
			EndIf
		
			aAcrescimo[2] := M->LQ_JUROS	// Percentual do acrescimo
	
	        LJ7AjustaTroco()
	
	        //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	        //³ Ajusta os valores de PIS/COFINS caso Haja                    ³
	        //ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	        Lj7PisCof()
	
	        If aAcrescimo[1] > 0
	            M->LQ_JUROS := (aAcrescimo[1] * 100) / Lj7T_SubTotal(2)
	        EndIf
	
	        RestArea(aAreaSAE)
	
	    EndIf
	Else
	    MsgAlert(STR0201) //"Não existe nenhuma MultiNegociação cadastrada (Rotina LOJA760)"
	EndIf
	
	If Len(aPgtos) == 0
	    aPgtos := aBkPgtos
	EndIf
	
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Multinegociação                                   ³
	//³Realiza GetDescont, pegando o valor de desconto do³
	//³Objeto para calcular o valor final com desconto.  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nDescMn > 0
	    Lj7T_DescV( 2, nDescMn )
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta o valor Total da venda                                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	
	Lj7T_Total( 2, LJ7T_Total(2) - nDescMn )
Else
	MsgAlert(STR0207) //"É necessário "ZERAR PAGAMENTOS" antes de continuar com a Multi Negociação"
EndIf
Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7AtuLote    ºAutor  ³Vendas Clientes     º Data ³  20/12/06  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Atribui o lote para o campo do aCols na Venda Assistida 		 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cLote    = Lote do produto                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³NIL                      	                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7AtuLote(cLote)
	Local nPosLoteCTL := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL" })	//Posicao do Lote no aCols da Venda Assistida
	Default cLote 	  := ""

	aColsDet[n][aPosCpoDet[nPosLoteCTL][2]] := cLote
Return(Nil)
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ LjVldAdm	 ³ Autor ³ Vendas Clientes      ³ Data ³ 16/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida banco                                     		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LjVldAdm(aExp1)			 		              		  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ aExp1 - Informacoes da Adm Fin			 				  ³±±
±±³          ³ oExp2 - Objeto de banco     				 				  ³±±
±±³          ³ oExp2 - Objeto descricao de banco						  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjVldAdm(aDadosAdm, oBanco, oDescBa)

Local aRet 			:= {}             		//  retorno com desconto
Local nTamAE_COD    := TamSX3("AE_COD")[1]	// Tamanho do campo AE_COD

Default aDadosAdm 	:= {}
Default oBanco		:= Nil
Default oDescBa		:= Nil


If lLjDespa
	aRet := 	LJ803GetMen(Substr( aDadosAdm[1][5], 1, nTamAE_COD), aDadosAdm[1][11], Val(aDadosAdm[1][3]) )

	If Len(aRet) > 0
		aDadosAdm[1][9] 	:= aRet[1][1]
		aDadosAdm[1][10] 	:= aRet[1][2]
	EndIf

	aRet := 	LJ803GetMen(Substr( aDadosAdm[1][5], 1, nTamAE_COD), '' , Val(aDadosAdm[1][3]), .T.)

	If Len(aRet) > 0
		oBanco:lVisible 	:= .T.
		oDescBa:lVisible 	:= .T.
		oBanco:SetFocus()
	Else
		oBanco:lVisible  	:= .F.
		oDescBa:lVisible 	:= .F.
		aDadosAdm[1][9]		:= 0
	EndIf
EndIf

Return(.T.)
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³LJ701VlF3	 ³ Autor ³ Vendas Clientes      ³ Data ³ 16/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida banco F3                                     		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LjVldAdm(aExp1)			 		              		  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ701VlF3()

Local aRet := {} 			//	Retorno com desconto
Local nTamAE_COD    := TamSX3("AE_COD")[1]	// Tamanho do campo AE_COD
Local aDadosAdm		:= GetaAdmF3()			// Dados Administradora
Local lAutoExB		:= IsBlind()		// Verifica se a rotina sera executada via execauto ou nao


aRet := LJ803GetMen(Substr( aDadosAdm[1][5], 1, nTamAE_COD), '' , Val(aDadosAdm[1][3]), .T.)

If Len(aRet) > 0

	aDadosAdm[1][11] := LJ803Tela(aRet)

	aRet := LJ803GetMen(Substr( aDadosAdm[1][5], 1, nTamAE_COD), aDadosAdm[1][11], Val(aDadosAdm[1][3]))

	DbSkip(-1)

Else
	If !lAutoExB
		Alert(STR0181) // "Não exite Banco cadastrado para essa Administradora Financeira"
	Else
		Conout(STR0181) // "Não exite Banco cadastrado para essa Administradora Financeira"
	Endif
EndIf

Return(.T.)
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³LJ701VldBc ³ Autor ³ Vendas Clientes      ³ Data ³ 16/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida banco F3                                     		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ LJ701VldBc(aExp1)			 		              		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ aExp1 - Informacoes da Adm Fin			 				  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LJ701VldBc(aDadosAdm)

Local lRet := .F.		// Retorno da fução
Local aRet := {} 		// retorno com desconto
Local nTamAE_COD    := TamSX3("AE_COD")[1]	// Tamanho do campo AE_COD

Default aDadosAdm := {}

If Empty(aDadosAdm[1][11])
	lRet := .T.
Else

	aRet := LJ803GetMen(Substr( aDadosAdm[1][5], 1, nTamAE_COD), aDadosAdm[1][11], Val(aDadosAdm[1][3]))

	If Len(aRet) > 0
		aDadosAdm[1][9] 	:= aRet[1][1]
		aDadosAdm[1][10] 	:= aRet[1][2]
		lRet := .T.
	Else
		lRet := .F.
	EndIf

EndIf

Return(lRet)
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³GetaAdmF3	 ³ Autor ³ Vendas Clientes      ³ Data ³ 16/03/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida variaveis f3                                		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ GetaAdmF3(aExp1)			 		              		  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function GetaAdmF3()

Return(aDadosF3)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjVlNrCertºAutor  ³Microsiga           º Data ³  22/06/10   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida o numero do certificado das retencoes (Localizado)  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjVlNrCert( cNumCert, cFormaPg )

Local cMvTpRet	:= SuperGetMV("MV_LJCTRET",,"RI|RG|RB|RS")
Local lRet		:= .T.
Local aAreaSFE	:= {}
Local lAutoExB	:= IsBlind()	// Verifica se a rotina sera executada via execauto ou nao

If ( cPaisLoc <> "BRA" .AND. cFormaPg $ cMvTpRet)
	aAreaSFE := SFE->( GetArea() )
	SFE->( DBSetOrder(1) )
	If SFE->( DbSeek(xFilial("SFE")+ cNumCert ) ) .OR. ( aScan(aPgtosSint, {|x| x[1] $ cMvTpRet .AND. IIf(Len(x[6]) > 0, x[6][4] == cNumCert, .F.) } ) > 0 )
		If !lAutoExB
			MsgAlert(STR0175) // O número do certificado de retenção já existe.
		Else
			Conout(STR0175) // O número do certificado de retenção já existe.
		Endif
		lRet := .F.
	EndIf
	RestArea( aAreaSFE )
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ LjValidPer   ºAutor  ³Vendas Clientes     º Data ³ 20/01/2012 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Realiza a validacao para desconto no aCols            		 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ nExp1 -	Opcao escolhida	de desconto                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ lRet  -  Retorno da funcao de validacao .T. ou .F.            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function LjValidPer( nOpcDesc )

Local aDesc 		:= {}				// Array com as informacoes de desconto
Local lRet 			:= .F.				// Retorno da funcao
Local nValorDesc 	:= 0				// Valor de desconto
Local nValFret		:= Lj7CalcFrete()

Default nOpcDesc 	:= 1					// Opcao escolhida

Do Case
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Mantem o valor do desconto³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Case nOpcDesc == 1
		nValorDesc := ( 100 * Lj7T_DescV(2) ) / LJ7T_SubTotal(2)
		aDesc := {"P",nValorDesc}

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica permissao para desconto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If LjProfile(11, Nil, aDesc, nValorDesc, Lj7T_DescV(2))
			Lj7T_DescP( 2, nValorDesc )
			Lj7T_Total( 2, (LJ7T_SubTotal(2) + nValFret) - Lj7T_DescV(2) )
			nValorDesc	:= 0
			lRet := .T.
		EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Mantem o percentual do desconto³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Case nOpcDesc == 2
		nValorDesc := ( LJ7T_SubTotal(2) * Lj7T_DescP(2) ) / 100
		aDesc := {"V",nValorDesc}

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica permissao para desconto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If LjProfile(11, Nil, aDesc, Lj7T_DescP(2), nValorDesc)
			Lj7T_DescV( 2, nValorDesc )
			Lj7T_Total( 2, (LJ7T_SubTotal(2) + nValFret) - nValorDesc )
			nValorDesc	:= 0
			lRet := .T.
		EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Zera o desconto no total³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Case nOpcDesc == 3
		Lj7T_DescP	( 2,0 )
		Lj7T_DescV	( 2,0 )
		Lj7T_Total	( 2, (LJ7T_SubTotal(2) + nValFret) )
		lRet := .T.
	EndCase

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ LjRetLj7T   ºAutor  ³Vendas Clientes     º Data ³ 22/01/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Restaura os valores originais do array aTotais, quando o usua-º±±
±±º			 | -rio clicar no botao Cancelar da Forma de Pagamento. Usado	º±±
±±º			 | somente quando for a nova regra de desconto					º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LjTelaAltPg													º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ aExp1 -	Array aTotais com os valores antigos				º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjRetLj7T()

Local nTipoDesc := 1
Local lLjGetDFP	:= FindFunction("LjGetDesFP")   //LOJA3026

//somente reseta os pagamentos, se houver desconto pela regra desconto varejo
If !Empty(aRetLj7T) .AND. lLjGetDFP .AND. (LjGetDesFP(1) .OR. LjGetDesFP(2) .OR. LjGetDesFP(3) .OR. LjGetDesFP(4))
	Lj7T_SubTotal(2, aRetLj7T[2] )	//Sub-Total
	Lj7T_DescP(2, aRetLj7T[3] )		//Desconto em porcentagem
	Lj7T_DescV(2, aRetLj7T[4] )		//Desconto em valor
	Lj7T_Total(2, aRetLj7T[5] )		//Total

	//se houver porcentagem ou valor de desconto, eh desconto no Total
	If aRetLj7T[3] > 0 .OR. aRetLj7T[4] > 0
		nTipoDesc := 2
	Else
		nTipoDesc := 1
	EndIf

	aDesconto := { nTipoDesc, Lj7T_DescP(2), Lj7T_DescV(2) }
EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7BDtVenc  ºAutor  ³Vendas Clientes     º Data ³ 19/03/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se é necessário recalcular a data de vencimento da  º±±
±±º			 | parcela no array de pagamentos... realiza esse processo para º±±
±±º			 | todas as parcelas da administradora financeira que está em   º±±
±±º			 | processo de avaliação indicado pela segunda posição nPos     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Lj7GrvVenda													º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ aExp1 -	array de pagamentos aPgtos geral                    º±±
±±ºParametros³ nExp2 -	posição em que a rotina está processando na gravaçãoº±±
±±º          ³  da venda  			                      					º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VcDUtil( aPgtos, nPos )

Local nParc 		:= 0	// numero da parcela
Local nPosPg 		:= 1 	// posicao no array de pagamentos
Local nTamPgtos 	:= 0	// numero de posições no array de pagamentos
Local dDatRet		:= CtoD('')

Default aPgtos 		:= {}
Default nPos   		:= 0

If nPos <> 0 .And. Len( aPgtos ) > 0 .And. ; // garante que os valores dos parâmetros sejam possíveis de avaliar
	( aScan( aVldVencPc, {|x| x==aPgtos[nPos,8]+aPgtos[nPos,3]}) == 0 ) .And. ; // verifica se o Id do cartão já teve as datas de vencimento das parcelas recalculadas
	SAE->( DbSeek( xFilial('SAE')+SubStr(aPgtos[nPos,4,5],1,TamSX3('AE_COD')[1]) ) ) // posiciona na Adm. Financeira em avaliação

	//--------------------------------------------------------------
	//  Verifica se o vencimento das parcelas é permitido somente
	// em dias úteis SAE->AE_DIAUTIL=='2'
	//  Sendo essa situação, recalcula as datas de vencimentos considerando
	// a condição
	If SAE->( FieldPos( 'AE_DIAUTIL' ) ) > 0 .And. SAE->AE_DIAUTIL == '2'

		nTamPgtos 	:= Len( aPgtos )

		//------------------------------------------------------
		//  Realiza o recálculo das datas de vencimento
		// considerando o número da parcela em que está
		// e a Adm. Financeira da posição do array de pagamentos
		While nPosPg <= nTamPgtos

			// Identifica se é o mesmo cartão em avaliação no aPgtos pelo Id e a Forma
			// Isso porque posso ter debito e credito com o mesmo ID
			If (aPgtos[nPos, 8]+aPgtos[nPos,3] == aPgtos[nPosPg, 8]+aPgtos[nPosPg,3])
				nParc++
				If nModulo == 12 .AND. Len(aPgtos[nPosPg,4]) > 0
					dDatRet := LjAvDUteis(aPgtos[nPosPg,4,2],nParc)
					If !Empty(dDatRet)	// Protecao para nao adicionar datas em branco
						aPgtos[nPosPg, 1] := dDatRet
					EndIf
				EndIf
			EndIf

			nPosPg++
		End
							// ID + FORMA
		aAdd( aVldVencPc, aPgtos[nPos,8]+aPgtos[nPos,3] ) // adiciona o Id do cartão aos itens que tiveram os vencimentos recalculados
	EndIf
EndIf

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ LjAvDUteis  ºAutor  ³Vendas Clientes     º Data ³ 19/03/2013 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Recalcula a data vencimento da parcela caso haja Adm. Finan. º±±
±±º			 | esteja configurada para vencimento somente em dias úteis     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Lj7VcDUtil													º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ dExp1 -	Dia inicial para cálculo das parcelas				º±±
±±ºParametros³ nExp2 -	quantidade de parcelas a ser calculado 				º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjAvDUteis( dDiaIni, nParc )

Local nPosPg 		:= 0	// Posição em validação no array de pagamentos

Default dDiaIni 	:= CtoD('')
Default nParc 		:= 0

If dDiaIni <> CtoD('') .And. nParc > 0

	//--------------------------------------------------------
	//  Calcula o vencimento considerando se a data inicial de
	// contagem dos dias é útil e se o vencimento também é dia
	// útil
	For nPosPg := 1 To nParc
		dDiaIni := DataValida( DataValida( dDiaIni, .T. ) + If( nPosPg==1, 0, 30 ), .T. )
	Next nPosPg
EndIf

Return dDiaIni

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ LjSelAdmRG  ºAutor  ³Vendas Clientes     º Data ³ 03/Out/2013º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Exibe tela para que o usuario selecione a Adm. Financeira    º±±
±±º			 | quando escolhida a forma de pagamento (CC/CD), para saber se º±±
±±º			 | deve ser aplicado desconto configurado na Regra de Desconto  º±±
±±º			 | quando a regra for configurada associando Adm. Financeiras.  º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjSelAdmRG(cFormPagto,lContinua,cRGAdmFin, cCondicao, cFormaId)
Local oDlgFPAdm
Local oCmbADMs
Local aAdmsFin 	:= {}
Local aAdminist	:= {}
Local cAdmFin 	:= ""
Local lConfirm	:= .F.
Local nTamAE_COD:= TamSX3("AE_COD")[1]
Local aAreaSE4 := {}       //WorkAreaSE4
Local cTipoAdm	:= ""
Local nPosAE_MSBL	:= SAE->(FieldPos( "AE_MSBLQL" ) )														// Verifica se existe o campo AE_MSBLQL
Local aAreaSAE	:= {} //WorkArea SAE
Local nPosAdm	:= 0  //Posicao da adm da RG

Default cCondicao := ""
Default cFormaID  := ""

//Se informou a condição de pagamento, busca a condição
If Empty(cFormPagto) .AND. !Empty(cCondicao)
	aAreaSE4 := SE4->(GetArea())
	cFormPagto := RTrim(Posicione("SE4",1,xFilial("SE4")+M->LQ_CONDPG,"SE4->E4_FORMA"))
	RestArea(aAreaSE4)
	//Busca as Administradoras Financeiras cadastradas
EndIf


If Len(aAdmsFinRG) > 0
	If !Empty(cFormaId) .AND. ( nPosAdm := aScan( aAdmsFinRG, {|x| AllTrim(x[3])+AllTrim(x[1]) == AllTrim(cFormaID)+AllTrim(cFormPagto) } ) ) > 0
		cRGAdmFin := aAdmsFinRG[nPosAdm][2]
	ElseIf !SuperGetMV("MV_TEFMULT") .AND. ( nPosAdm := aScan( aAdmsFinRG, {|x| AllTrim(x[1]) == AllTrim(cFormPagto) } ) ) > 0
		cRGAdmFin := aAdmsFinRG[nPosAdm][2]
	EndIf

EndIf


If Empty( cRGAdmFin)

	If Type("aAdmFinanc") != "U"
		aAdmsFin := aClone(aAdmFinanc)
	Else

	    aAreaSAE	:= SAE->(GetArea())
		SAE->( DbSetOrder(1) )	//AE_FILIAL + AE_COD
		SAE->( DbSeek(xFilial("SAE")) )

		While SAE->AE_FILIAL == xFilial("SAE") .AND. SAE->( !Eof() )
			If !(AllTrim(SAE->AE_TIPO) $ MVCHEQUE .OR. IsMoney(SAE->AE_TIPO))
			    If SX5->(DbSeek(xFilial("SX5")+"24"+AllTrim(SAE->AE_TIPO)))
					If ( nPosAE_MSBL > 0 .AND. SAE->AE_MSBLQL <> "1" ) .OR. nPosAE_MSBL == 0
						aAdd( aAdmsFin, { AllTrim(SAE->AE_TIPO), SAE->AE_DESC, SAE->AE_COD } )
			    	EndIf
				EndIf

			EndIf

			SAE->(DbSkip())
		End
		If Len( aAdmsFin ) > 1
			aSort( aAdmsFin, , , { |x,y| x[1] + Upper(x[2]) < y[1] + Upper(y[2]) })
		EndIf
		RestArea(aAreaSAE)
	EndIf

	aEval(aAdmsFin, { |adm| cTipoAdm := cTipoAdm + ";" + RTrim(adm[1]) })
	If !Empty(cFormPagto) .And. (cFormPagto $ _FORMATEF .OR. cFormPagto $ cTipoAdm )
		aEval( aAdmsFin, {|x| If( AllTrim(x[1])==AllTrim(cFormPagto),aAdd(aAdminist, x[3] + " - " + x[2]),Nil) } )

		DEFINE MSDIALOG oDlgFPAdm FROM 12, 20 TO 20, 60 TITLE STR0065 //"Financiadora"

		@ 05, 05 SAY STR0198 OF oDlgFPAdm PIXEL //"Selecione a Administradora para esta forma de pagamento."

		@ 21, 10 SAY STR0070 OF oDlgFPAdm PIXEL //"Administradora:"
		@ 20, 55 MSCOMBOBOX oCmbADMs VAR cAdmFin ITEMS aAdminist SIZE 100,40 OF oDlgFPAdm PIXEL

		DEFINE SBUTTON oBt1 FROM 045, 088 TYPE 1 ACTION (lConfirm := .T., oDlgFPAdm:End()) ENABLE OF oDlgFPAdm //Botao Confirma
		DEFINE SBUTTON oBt2 FROM 045, 121 TYPE 2 ACTION (oDlgFPAdm:End()) ENABLE OF oDlgFPAdm //Botao Cancela

		ACTIVATE MSDIALOG oDlgFPAdm CENTERED

		If lConfirm
			lContinua := .T.
			cRGAdmFin := Left(cAdmFin,nTamAE_COD)
			aAdd( aAdmsFinRG, {cFormPagto, cRGAdmFin, cFormaId} )
		Else
			lContinua := .F.
		EndIf
	EndIf

EndIf
Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ LjSetLj7T   ºAutor  ³Varejo			    º Data ³ 28/03/2014 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Alimentamos o array estatico aRetLj7T, que eh usado para		º±±
±±º			 |	armazenar os valores do Rodape do Venda Assistida			º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ nExp1 -  Reseta(0) ou alimenta(1) o array aRetLj7T			º±±
±±º			 ³ cExp1 -	numero do orcamento									º±±
±±º			 ³ nExp2 -	SubTotal do Rodape					 				º±±
±±º			 ³ nExp3 -	Valor de Desconto do Rodape			 				º±±
±±º³ 		 | nExp4 -	Percentual de Desconto do Rodape	 				º±±
±±º			 ³ nExp5 -	Total de Mercadorias do Rodape		 				º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjSetLj7T(	nOpcao	, cNum	, nSubTotal, nVDesc,;
					nPDesc	,nTotal	)

Default nOpcao		:= 0
Default cNum		:= ""
Default nSubTotal	:= 0
Default nVDesc		:= 0
Default nPDesc		:= 0
Default nTotal		:= 0

aRetLj7T := Array(5)

If nOpcao == 0
	aRetLj7T := {}
Else
	aRetLj7T[1] := cNum
	aRetLj7T[2] := nSubTotal
	aRetLj7T[3] := nVDesc
	aRetLj7T[4] := nPDesc
	aRetLj7T[5] := nTotal
EndIf

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³ Lj7IcmsSol  ºAutor  ³ Varejo             º Data ³ 08/Abr/2014º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Retorna o valor de ICMS Solidario da venda.                  º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7IcmsSol(aItens,lVerDel)
Local aArea 	:= {}
Local aAreaSF4 	:= {}
Local nInd		:= 0
Local nTotItens := 0
Local nPosDel	:= 0
Local nTotICMSol:= 0 //Acumula o total de ICMS Solidario da venda
Local nPosProd	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]

Default aItens 	:= If( Type("aCols")<>"U", aCols, {} )
Default lVerDel := Type("aCols")<>"U"

nTotItens 	:= Len(aItens)
nPosDel		:= If(nTotItens>0, Len(aItens[1]), 0)

If MaFisFound("NF") .And. (!lVerDel .Or. nPosDel > 0)
	aArea 		:= GetArea()
	aAreaSF4 	:= SF4->(GetArea())

	DbSelectArea("SF4")
	SF4->( DbSetOrder(1) )

	For nInd:=1 To nTotItens
		If (lVerDel .And. aItens[nInd][nPosDel]) .Or. (Empty( aItens[nInd][nPosProd] )) .Or. !(MaFisFound("IT",nInd))//Ignora itens deletados e Ignora Linhas em Branco
			Loop
		EndIf

		If SF4->( DbSeek(xFilial("SF4")+MaFisRet(nInd, "IT_TES")) ) .And. SF4->F4_INCSOL != "N"
			nTotICMSol += MAFisRet(nInd, "IT_VALSOL")
		EndIf
	Next nInd

	RestArea(aAreaSF4)
	RestArea(aArea)
EndIf

Return nTotICMSol

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7SetIPEC  ºAutor  ³ Varejo             º Data ³ 31/Jul/2014º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Seta o Valor do IPI Calculado.                                º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SetIPEC(nValor)
Default nValor := 0

nIPIEC := nValor

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7GetIPEC  ºAutor  ³ Varejo             º Data ³ 31/Jul/2014º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Retorna o Valor do IPI Calculado                             º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7GetIPEC()

Return nIPIEC

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³ Lj7AltCond  ºAutor  ³ Varejo             º Data ³ 31/10/2014 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua as atualizacoes para Regra de Desconto na Condicao de º±±
±±           ³ Pagamento.                                                   º±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function Lj7AltCond()

Local aArea      	:= GetArea()          	 			//Area atual do sistema
Local aAreaACO  	:= ACO->(GetArea())     	 			//Area da tabela ACO
Local cCondCust	:= Space(TamSx3("LQ_CONDPG")[1])	//Condição de Pagamento customizada
Local cCondPad 		:= SuperGetMv("MV_CONDPAD",, .F.) 	//Condição de Pagamento padrão 
Local lConcomit	:= SuperGetMv("MV_LJVACC",, .F.) 	//Venda concomitante
Local cTabPad		:= SuperGetMv("MV_TABPAD",, "")		//Tabela de Preco Padrao
Local cMvLjTGar	:= SuperGetMV("MV_LJTPGAR",, "GE") //Tipo Garantia Estendida
Local cMvLjTSF	:= SuperGetMV("MV_LJTPSF",, "SF") 	//Tipo Servico Financeiro
Local nPosDesc 	:= aScan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_DESC"})
Local nPosValDe	:= aScan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_VALDESC"})
Local nPosProd	:= aScan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_PRODUTO"})
Local nPosSubTo	:= aScan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_VLRITEM"})
Local nI			:= 0 	//Contador
Local nSubAnt		:= 0 	//SubTotal anterior
Local nPerDesAnt	:= 0 	//Percentual de desconto anterior
Local nValDesAnt	:= 0 	//Valor desconto anterior
Local nValDesc	:= 0 	//Valor de desconto no Total da Venda
Local nTotAnt		:= 0 	//Valor Total anterior
Local nSubTotal	:= 0 	//Valor SubTotal
Local nValTot		:= 0 	//Valor Total
Local lRet			:= .T. //Retorno da rotina
Local lMvArrefat	:= (SuperGetMv("MV_ARREFAT") == "S")

Static cCondAntX := Space(TamSx3("LQ_CONDPG")[1]) //Condição de Pagamento anterior

ACO->(dbSetOrder(2))

//Nao executa atualização para venda concomitante
If !lConcomit
	//Se chamado pelo Valid do campo customizado, atualiza M->LQ_CONDPG com Condição de Pagamento do campo
	If !Empty(ReadVar()) .And. ReadVar() <> "M->LQ_CONDPG" .And. Left(ReadVar(), 5) == "M->LQ"
		cCondCust := &(ReadVar())

		If ValType(cCondCust) == ValType(SLQ->LQ_CONDPG) .And. Len(cCondCust) == TamSx3("LQ_CONDPG")[1]
			M->LQ_CONDPG := cCondCust
		EndIf
	EndIf

    If Empty(cCondAntX)
    	cCondAntX := cCondPad
    EndIf
    
    If M->LQ_CONDPG <> cCondAntX
	//Verifica se existe Regra de Desconto para a Condição de Pagamento atual e anterior
	//Necessario verificar a condição anterior pois a atual pode não fazer parte da regra de desconto
	If (!Empty(M->LQ_CONDPG) .And. ACO->(dbSeek(xFilial("ACO") + cTabPad + M->LQ_CONDPG))) .Or.;
				(!Empty(cCondAntX) .And. ACO->(dbSeek(xFilial("ACO") + cTabPad + cCondAntX)))

		//Ajuste para manter a Condição de Pagamento original quando entrar na tela de Pagamentos
		//Se cCondAntX estiver vazio, tambem limpa conteudo de M->LQ_CONDPG pois indica que é a primeira troca de telas
		//Será executado apenas na troca de telas
		If Empty(ReadVar()) .And. M->LQ_CONDPG <> cCondAntX
			M->LQ_CONDPG := cCondAntX
		EndIf

		//Armazena condição de Pagamento atual
		cCondAntX := M->LQ_CONDPG
		
		//Zero os descontos
		nPerDesAnt	:= Lj7T_DescP(2,0)
		nValDesAnt	:= Lj7T_DescV(2,0)

		//Atualiza aCols
		For nI := 1 To Len(aCols)
			If !aCols[nI][Len(aHeader) + 1] .And. !Empty(aCols[nI][nPosProd]) //Atualiza itens não deletados e com produto selecionado
				n := nI //Altera linha

				//Nao atualiza Garantia Estendida e Servico Financeiro
				If !Posicione("SB1", 1, xFilial("SB1") + aCols[n][nPosProd], "B1_TIPO") $ cMvLjTGar + "|" + cMvLjTSF
					//Zera desconto no item
					aCols[n][nPosDesc] 	:= 0
					aCols[n][nPosValDe] 	:= 0

					//Atualiza item
					Lj7Prod(.F.)
				EndIf

				//Atualiza SubTotal da venda
				nSubTotal += aCols[n][nPosSubTo]
			EndIf
		Next nI
		
		//Armazena informacoes anteriores a atualização
		nSubAnt		:= LJ7T_SubTotal(2)
		nPerDesAnt	:= Lj7T_DescP(2)
		nValDesAnt	:= Lj7T_DescV(2)
		nTotAnt 	:= LJ7T_Total(2)

		//Armazena valor de desconto com tratamento de arredondamento
		If lMvArrefat
			nValDesc 	:= Lj7Arred(2, 3, (nSubTotal / 100) * nPerDesAnt)
		Else
			nValDesc 	:= nValDesAnt // Não há necessidade de recalculo de desconto 
		EndIf
		nValTot	:= nTotAnt - (nSubAnt - nValDesAnt) + (nSubTotal - nValDesc)

		//Atualiza valores
		LJ7T_SubTotal(2, nSubTotal) //SubTotal da Venda
		Lj7T_DescP(2, nPerDesAnt) 	//Percentual de desconto
		Lj7T_DescV(2, nValDesc) 		//Valor de desconto
		LJ7T_Total(2, nValTot) 		//Total da Venda
	EndIf
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//Recuperando area do sistema                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
RestArea(aAreaACO)
RestArea(aArea)

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³ LjVldPgto   ºAutor  ³ Varejo             º Data ³ 31/08/2015 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao para validar as informacoes de telinha de pagamento noº±±
±±º          ³ momento que clica no botao confirmar.                        º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LjVldPgto(dData,nValor,cForma,nParc,cCodForma,nBkpVlr)
Local lRet := .T.
Local cMV_LJPGTRO 	:= AllTrim(SuperGetMV("MV_LJPGTRO",,IIf( cPaisLoc <> "BRA","", "R$")))
Local lTrocoLiq  	:= SuperGetMV( "MV_LJTRDIN", , 0 ) > 0 //Gera troco em dinheiro do valor líquido
Local cMsg 			:= ""
Local lRecPar		:= SuperGetMV("MV_LJRECPA",,.T.)                   // Recalcula valor das Parcelas
Local nPosObj 		:= IIF(IsBlind(),1,IIf(lVisuSint .AND. Type("oPgtosAna")=="O", oPgtosAna:nAt , oPgtos:nAt ))
Local nTotParc    	:= 0
Local nTotAnt 		:= 0

If nValor > nBkpVlr .AND. lRecPar
	aEval( aPgtos, { |p|  nTotParc := nTotParc +  p[2] }) //Total das Parcelas
	
	If nPosObj > 1 
		aEval( aPgtos, { |p|  nTotAnt := nTotAnt +  p[2] }, 1, nPosObj-1) //Total das Parcelas Anteriores
	EndIf
	
	If nTotAnt + nValor > nTotParc
		lRecPar := .F. //Não é possível recalcular parcelas , pois o valor da parcela é superior à soma das parcelas, nesse caso deveria gerar troco
	EndIf
EndIf

If nValor > nBkpVlr .And.  (  !(Empty(cMV_LJPGTRO) .OR. cCodForma $ cMV_LJPGTRO) .AND. !lRecPar ) 
	MsgAlert(STR0203 + " '" + cCodForma + " - " + AllTrim(cForma) + "'" + CRLF + STR0205,STR0015) //#"Não é permitido gerar troco para a forma de pagamento "" A forma de pagamento que permite troco deve estar cadastrada no parâmetro MV_LJPGTRO"##"Atenção"
	lRet := .F.
ElseIf nValor > nBkpVlr  .AND. lTrocoLiq  .AND. !IsMoney(cCodForma).AND. !lRecPar
	
	MsgAlert(STR0203 + " '" + cCodForma + " - " + AllTrim(cForma) + "'" + CRLF + STR0206,STR0015) //#"Não é permitido gerar troco para a forma de pagamento "" Sistema configurado para gerar troco líquido em Dinheiro. Informe dinheiro como a última forma de pagamento para gerar troco."##"Atenção"
	lRet := .F.
EndIf

If lRet .AND.  nValor > nBkpVlr .AND. Empty(Lj7GetTrcForm()) .AND. !lRecPar //Se não recalcular a parcela seta o troco
	Lj7SetTrcForm(cCodForma)
EndIf


If lRet .And. ExistBlock("LJVLDPGT")
	lRet := ExecBlock( "LJVLDPGT",.F.,.F., { dData,nValor,cForma,nParc } )
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³ Lj7SetTrcFormºAutor  ³ Varejo             º Data ³ 29/12/2016º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao para indicar qual forma de pagamento receberá o troco  ±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7SetTrcForm(cForma)
If !Empty(cForma)
	cLj7TrcForm := cForma
	cLj7NumTrc := M->LQ_NUM
Else
	cLj7TrcForm := ""
	cLj7NumTrc := ""
EndIf

Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³ Lj7GetTrcFormºAutor  ³ Varejo             º Data ³ 29/12/2016º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao para indicar qual forma de pagamento receberá o troco  ±±
±±           ³ que está assocada à venda corrente							±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7GetTrcForm()
Local cRet := ""
//Somente retorna a forma se for da mesma venda
If cLj7NumTrc == M->LQ_NUM
	cRet := cLj7TrcForm
Else
	//Zera a forma do troco
	Lj7SetTrcForm("")
EndIf

Return cRet

/*/{Protheus.doc} Lj7BClean
Reinicia variaveis Static do LOJA701B
@type		function
@author  	Lucas Novais	
@version 	P11.80
@since   	25/09/2017
@obs		
/*/
Function Lj7BClean()
lCalcFrete := .T.
Return Nil

/*/{Protheus.doc} LjSetnOpcRot()
Atribui valor da variavel Statica nOpcRotina
@author  João Marcos Martins
@version P12.17
@since   10/10/2018
@return  Retorna o valor da variavel Statica nOpcRotina
/*/
//--------------------------------------------------------
Function LjSetnOpcRot( nOpc )
nOpcRotina := nOpc
Return 

/*/{Protheus.doc} LjGetnOpcRot()
Retorna o valor da variavel Statica nOpcRotina
@author  João Marcos Martins
@version P12.17
@since   10/10/2018
@return  Retorna o valor da variavel Statica nOpcRotina
/*/
//--------------------------------------------------------
Function LjGetnOpcRot( )
Return nOpcRotina
