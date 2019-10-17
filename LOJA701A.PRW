#INCLUDE "LOJA701A.CH"
#INCLUDE "PROTHEUS.CH"
#INCLUDE "MSMGADD.CH"
#INCLUDE "TCBROWSE.CH"

Static aMoeda
Static lFreteAlt	:= .F.												// Indica que ocorreu alteracao no valor do frete, despesa ou seguro.
Static lCenVenda 	:= SuperGetMv("MV_LJCNVDA",,.F.)
Static nDescAnt															// Bkp do valor de desconto Global
Static oMotivoDes	:= Nil
Static lMvljpdvpa	:= LjxBGetPaf()[2] 									// Indica se é pdv
Static lValidSenha  := .F.												// Variavel logica de validacao de senha
Static lLjMVRecIss	:= SuperGetMV("MV_LJRECIS",,.F.)					// Indica se ha desconto do iss no financeiro
Static lLjVfe		:= SuperGetMV("MV_LJVFE",,.F.)						// #VFE - Verifica se a rotina de Venda fora do estado esta ativa
Static lLj7IsNoFun	:= ExistFunc("Lj7IsNoFun")
Static lDtFontes	:= NIL
Static aTesInt		:= {}												// Array com as validações da TES Inteligente
Static lIsPafNfce	:= ExistFunc("STBPafNfce") .And. STBPafNfce()										//Usa NFC-e com PAF ?
Static lMFE			:= IIF( ExistFunc("LjUsaMfe"), LjUsaMfe(), .F. )		//Se utiliza MFE
Static lEmitAvsGE   := .F.	//Se emitiu aviso de Garantia Estendida/Serv. Fin. não permitido, SOMENTE VENDA DIRETA em SIGAFAT


/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7Prod   ºAutor  ³ Vendas Clientes    º Data ³  01/07/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida o produto inserido no aCols.                        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³ ExpL1: Indica se a chamada foi a partir de um X3_VALID     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ ExpL1: Valida se o produto informado e valido              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Prod( 	lValid		, lBonus	, lGarantia	,	lLjGrid		,;
					lSugestao	, nKit		, cProdKit	,	nItemKit	,;
					lItemKit	)

Local aArea	  		:= GetArea()																// Armazena area atual (alias, order e recno)
Local lRet			:= .T.																		// Retorno da funcao
Local nItem 		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})][2]		// Posicao da coluna Item
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosDescri	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESCRI"})][2]		// Posicao da Descricao do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]		// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local nPosUM		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_UM"})][2]			// Posicao da Unidade de Medida
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]		// Posicao do percentual de desconto
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do valor de desconto
Local nPosVlrItem	:= aPosCpo[Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_VLRITEM"})][2]	// Posicao do valor do item
Local nPosLPre		:= Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_CODLPRE"})				// Posicao do código de lista de presentes
Local nPosPrdCob	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRDCOBE"})				// Posicao do codigo do Produto Cobertura
Local nPosNSerie   	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_NSERIE" })				// Posicao do Numero de serie
Local nGarant	    := 0																		// Posicao do valor da garantia
Local nSerie	    := 0																		// Posicao do valor de série
Local nPosDtReserva	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_RESERVA"})				// Posicao do codigo da reserva
Local nPosDtLocal  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCAL"})				// Posicao do local (armazem)
Local nPosValePre	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALEPRE"})				// Posicao do codigo do Vale Presente
Local nPosPrcTab	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})				// Posicao do Preco de Tabela
Local nMoedaPrv     := 1																		// Armazena a moeda usada no Prc. Venda
Local lEstNeg 		:= (SuperGetMV("MV_ESTNEG",,"S") == "S") .OR. lMVLJPDVPA					// Indica se permite vender com estoque negativo
Local lTrcMoeda     := SuperGetMV("MV_TRCMOED",,.T.)											// Indica se permite escolha de moeda
Local cLocal 		:= ""																		// Armazena o local padrao
Local cProduto 		:= Space(TamSx3("LR_PRODUTO")[1])											// Armazena cod. do produto
Local lVAssConc	 	:= LjVassConc()																// Indica se o cliente utiliza a Vda Assistida Concomitante
Local lLJ7036		:= ExistBlock("LJ7036")														// Ponto de entrada antes da impressao concomitante
Local lTLJ7036		:= ExistTemplate( "LJ7036" )												// Ponto de entrada antes da impressao concomitante
Local lRetPE		:= .T.																		// Retorno do ponto de entrada
Local lValEst		:= .F.																		// Retorno da funcao Lj7VerEst (Verifica se o item tem etoque)
Local lLJ7041		:= ExistBlock("LJ7041")														// Verifica a existencia do P.E.
Local cValePre		:= Space(15)																// Variavel para auxiliar na captura de codigo de vale presente
Local xLocal		:= ""																		// Variavel auxiliar ao P.E. LJ7041 que permite personalizar o almoxarifado de saida do produto
Local nBkpVlruni   	:= 0      	 	  					 				 	   					// Backup do campo Valor Unitario do Produto no aCols
Local nBkpQuant     := 0	   	  					 			 		 						// Backup do campo Quantidade o Item no aCols
Local nBkpDesc      := 0	  		   			   						  						// Backup do campo Desconto do produto no aCols
Local nBkpValDesc   := 0	 												 					// Backup do campo Valor de Desconto  no aCols
Local cBkpDescri	:= Space( TamSx3("LR_DESCRI")[1] )											// Backup do campo Descricao do Produto no aCols
Local cBkpUm   		:= ""	 												 					// Backup do campo Unidade de Medida do Produto no aCols
Local cBkpProd		:= ""	 											 						// Backup do campo Produto no aCols
Local nBkpVlItem	:= 0	 											 						// Backup do campo Valor dO Item  no aCols
Local lPcMult       := .F.																		// Verifica se o produto digitado na consulta existe.
Local nPrecoTab		:= 0
Local nRet			:= 0
Local nAux			:= 0
Local cRetorno		:= ""
Local lDescCab      := .F.											   							// Indica se houve desconto no total pela regra de desconto cenario de venda
Local xRet
Local oLJCLocker 	:= If( ExistFunc("LOJA0051") .And. SuperGetMV( "MV_LJILVLO",,"2" ) == "1", LJCGlobalLocker():New(), )
Local lSuVend		:= SuperGetMV("MV_LJSUAUT",,.F.) 											// sugestao de vendas automatica
Local nPosProvEnt	:= Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_PROVENT"})				// Posicao da provincia de entrega //ANDERSON
Local cBkpProvEnt	:= ""	 											 						// Backup do campo provincia de entrega
Local nTotalCF		:= 0                                                            		    // Total do Cupom Fiscal (Diferente do total da Nota Fiscal)
Local cEntrega		:= ""																		// Tipo de entrega do item
Local nPosEntrega	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ENTREGA"})][2]	// Posicao da Unidade de Medida
Local lExLegSP10	:= ExistFunc("Lj950SP10OK")													// Verifica a existencia da funcao que valida a legislacao paulista que limita o cupom fiscal em 10.000,00
Local lExTotalCF	:= ExistFunc("LJXTotalCF")													// Verifica a existencia da funcao que calcula o total do cupom fiscal
Local lAutoExA		:= IsBlind()																// Verifica se a rotina sera executada via execauto ou nao
Local lRetaPaf		:= LjNfPafEcf(SM0->M0_CGC) .AND. !lMvljpdvpa 								// Sinaliza se utiliza Retaguarda com PAF-ECF, para realizar o tratamento da concomitancia
Local lIsRecCel 	:= .F.																		// Indica que eh produto "Recarga de Celular"
Local nVlrRecarg 	:= 0																		// Valor da "Recarga de Celular" ou "Recarga de Cartao Presente" (Gift Card)
Local lGE			:= ExistFunc("LjUP104OK") .AND. LjUP104OK()									// Validação do Conceito Garantia Estendida
Local cMV_CLIPAD	:= SuperGetMV("MV_CLIPAD")													// Cliente Padrão
Local cMV_LOJAPAD	:= SuperGetMV("MV_LOJAPAD") 												// Loja PAdrão
Local cMvLjTGar	    := SuperGetMV("MV_LJTPGAR",,"GE") 											// Define se é tipo GE
Local cMsnErro		:= ""																		// Ponto de entrada pra habilitar a Garantia Estendida Default .T.
Local lLJ7081		:= IIF(ExistBlock("LJ7081"), Execblock( "LJ7081", .F., .F. ), .T.)     		// Garantia Estendida	Ponto de entrada pra habilitar a Garantia Estendida Default .T.
Local cMvLjTSF	    := SuperGetMV("MV_LJTPSF",,"SF") 											// Define se é tipo SF
Local nItGarant		:= 0																		// Produto possui garantia
Local lIsRecCP 		:= .F.																		// Indica que eh produto "Recarga de Cartao Presente (Gift Card)"
Local nPosPRedIc	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PREDIC"}) // %Redução da Base do ICMS 																	// Indica que eh produto "Recarga de Cartao Presente (Gift Card)"
//³Relase 11.5 - Cartao Fidelidade³
Local lLjcFid 		:= SuperGetMv("MV_LJCFID",,.F.) .AND. CrdxInt()							// Indica se a recarga de cartao fidelidade esta ativa
Local nX			:= 0 																		// Contador
Local nTotProd		:= 0																		// Total de produtos nao deletados no aCols
Local nPosNumcFi 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NUMCFID"})				// Posicao do Numero do cartao fidelidade
Local nPosDtsdFi 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DTSDFID"})				// Posicao da data de validade do saldo inserido
Local nPosVlrcFi 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VLRCFID"})				// Posicao do valor do saldo inserido
Local nPosLocaliz  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCALIZ"})				// Posicao do Localizacao
Local nNSerieDet  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NSERIE" })				// Posicao do Numero de serie
Local nPosDtValid  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DTVALID" })			// Posicao da Data de validade
Local nPosSubLote	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE"})				// Posicao do sublote do produto

Local lFTVD7041		:= ExistBlock("FTVD7041")													// Verifica a existencia do P.E.
Local lFTVD7036		:= ExistBlock("FTVD7036")													// Ponto de entrada antes da impressao concomitante
Local lTFTVD7036	:= ExistTemplate( "FTVD7036" )												// Ponto de entrada antes da impressao concomitante
Local nPosCodBar	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CODBAR"})				// Guarda codigo de barras do produto para otimizar geracao da NFce
Local cCodBar 		:= ""																		// Armazena cod. de barras do produto
Local lIntSynt 	 	:= SuperGetMV("MV_LJSYNT",,"0") == "1"	 									// Informa se a integracao Synthesis esta ativa
Local lEmitNfce		:= ExistFunc("LjEmitNFCe") .AND.  LjEmitNFCe()								// Sinaliza se utiliza NFC-e

//usada na Integracao Protheus x SIAC
Local lScCsPreco	:= .F.																		// Indica se a consulta de preco via WS esta habilitada

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Variaveis para uso Template Otica³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local cTipoIt		:= ""																		// Verifica o tipo do produto
Local lMargem       := SuperGetMV("MV_LJMARGE",,.F.) 											// Valida se considera a margem minIma no venda assistida.
Local nPosClasFis	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_CLASFIS"}) 				// Classificacao Fiscal do Produto
Local lLJ8099		:= ExistBlock("LJ8099")   													// Garantia Estendida	Ponto de entrada pra habilitar a Garantia Estendida Default .T.
Local lVPNewRegra 	:= ExistFunc("Lj7VPNew") .And. Lj7VPNew() 									// Verifica se utiliza as novas modificacoes da implementacao de Vale Presente, para imprimir o comprovante nao fiscal na venda de vale presente.
Local lGiftCard 	:= ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() 									// Verifica se permite utilizar a implementacao de Cartao Presente (Gift Card)
Local lSFinanc		:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)						// Valida implementação do servico financeiro
Local lVincServ		:= IIF(ExistFunc("Lj7GetServ"), Lj7GetServ(), .F.)
Local lNT2015002	:= ExistFunc("NT2015002")  													// Verifica se a funcao provisoria da NT2015/002 esta compilada (LOJNFCE)
Local lUseSat		:= LjUseSat()																// Usa Sat
Local nValorVP		:= 0																		// Valor do Vale Presente
Local aAreaSB1		:= {}																			// Variável Auxiliar
Local lIntegDef		:= lAutoExA .And. FWHasEAI("LOJA701",, .T., .T.) .AND. IIF( ExistFunc("Lj701GtInD") , Lj701GtInD(), IsInCallStack("LOJI701")) //Integracao via Mensagem Unica
Local lFtvdVer12	:= LjFTVD() 								   								//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local nPosKit       := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_KIT"})][2]   		//Posicao do parametro KIT


Default lValid		:= .T.																		// Indica se a chamada foi a partir de um X3_VALID
Default lBonus      := .F.                                                                  	// Indica se a Bonus
Default lLjGrid		:= .F.																		// Indica se foi digitado do grid
Default lGarantia	:= .T.    																	// Indica se é Garantia ou Sugestão de venda
Default lSugestao	:= .T.																		// Mostra a tela de sugestao de venda
Default nKit        :=  0         									                            // Controla a chamada a função Lj7Prod
Default cProdKit    := ""                                                                       // Atribuirá seu conteúdo a variavel cProduto, para que o sistema possa trabalhar o produto da acols do Kit
Default nItemKit    := 0                                                                        // Controla a posicao do produto no aCols
Default	lItemKit	:= .F.																		// Controla chamada da rotina LjInfoKit apenas para produto pai


// Limpa a variável estática
If Len(aCols) <= 1
	aTesInt := {}
EndIf 

If Type ("lAutomato")<> "L"
	lAutomato 	:= If(Type("lAutomatoX")<>"L",.F.,lAutomatoX)
EndIf

If !Empty(cProdKit)
	cProduto := AllTrim(cProdKit)
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o produto pertence ao kit ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistFunc("Lj7IsKit") .And. Type("oGetVA") == "O" .AND. (oGetVA:LMODIFIED .Or. !Empty(aCols[n][nPosKit]))  .And. !IsInCallStack("LJNFCELOT") //Quando Finalização de NFCE em Lote, a validação de KIT não deve ser executada neste ponto, pois a mesma e executada via rotina automatica. 
	If Lj7IsKit(aCols[n][nItem], aCols[n][nPosProd])
		If aCols[n][nPosVlUnit] > 0
			Alert(STR0114) // "Não é possível alterar este produto pois o mesmo pertence a um Kit de Produtos."
			lRet := .F.
		EndIf
	EndIf
EndIf

//indica se o Protheus pode consultar o preco de um produto no SIAC Store via WS
lScCsPreco := SuperGetMV("MV_SCINTEG",,.F.) .AND. SuperGetMV("MV_SCCSPRC",,.F.) .AND. ExistFunc("LJSCCSPRC")

//Para utilizar DAV eh necessario informar o CPF/CNPJ do cliente
// Se vier de lAutoexec, não é necessário checar DAV por causa da importação do uMov.me para o Sigaloja
If !lMvljpdvpa .AND. LjNfPafEcf(SM0->M0_CGC) .AND. !SuperGetMV("MV_LJPRVEN",,.F.) .AND.;
 	Empty(SA1->A1_CGC) .And. !(AllTrim(SA1->A1_EST) == "EX") .AND. !lFtvdVer12 .AND. (Type("lAutoExec") <> "L" .OR. !lAutoExec)
 	
	MsgStop( STR0081 + Chr(13) + STR0080)	//"Conforme previsto no Resquisito VI(ATO COTEPE/ICMS 0608):"  //"Para realizar um DAV é necessário informar cliente com CPF/CNPJ"
	lRet := .F.
EndIf

//³ Verifica se o tipo do produto inserido é OG e  ³
//³ chama a função do Template Otica para incluir  ³
//³ no aCols o conjunto Armação e Lentes direita e ³
//³ esquerda.									   ³
If HasTemplate("OTC")

	SB1->(dbSetorder(1))
	SB1->(dbSeek(xFilial("SB1")+M->LR_PRODUTO))

	cTipoIt := SB1->B1_TIPO

	If cTipoIt == "OG"
		T_ConjGlas(aCols)
	EndIf

EndIf

// NFC-e: Apresenta uma mensagem ao usuário, informando que se for ambiente de homologação,
// a Descrição do primeiro item da Nota Fiscal (tag:xProd) deve ser informada como
// "NOTA FISCAL EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL"
If (lEmitNFCe .Or. lIsPafNfce) .AND. lNT2015002 .AND. n == 1 .And. !lUseSat
	NT2015002(Nil, M->LR_PRODUTO)
EndIf

//Verifica se foi informado o codigo do produto
If "LR_PRODUTO" $ ReadVar()
	If Empty(&(ReadVar()))
		lRet := .F.
	EndIf
EndIf

If lRet
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Cria proteção para campos incluidos no fonte loja701³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lGE
		If Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_NSERIE"}) > 0
		    nSerie	    := aPosCpo[Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_NSERIE"})][2]	// Posicao do valor de série
		EndIf

		If Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"}) > 0
			nGarant	    := aPosCpo[Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_GARANT"})][2]	// Posicao do valor da garantia
		EndIf
	EndIf

	/*Executa Funcao Lj7VldUs que autoriza modificacoes
	nas celulas dos itens ja lancados por vendedores/usuarios.*/
	If !Lj7VldUs()
   		lRet := .F.
		Return lRet
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Caso a Consulta Multimida estaja ativada nao vai usar ³
	//³essa funcao.                                          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If HasTemplate("DRO")
		If T_DroSendPCM()
			lPcMult :=  ExistCPO("SB1",M->LR_PRODUTO,1)
			Return (lPcMult)
		EndIf
	Endif

	If nPosProvEnt > 0
		nPosProvEnt	:= aPosCpo[nPosProvEnt][2]		// Posicao da provincia de entrega
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Sendo o primeiro item digitado, busca para saber se existem³
	//³tabelas de preco ativadas                                  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Len(aCols) == 1 .AND. lCenVenda
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Limpa o array estatico do LOJA701E³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		LjxClFindT()
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Busca no LOJA701E se existem tabelas de preco ativa³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		LjxFindTab(M->LQ_CLIENTE, M->LQ_LOJA)
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se existe reserva para o produto. Se existir nao  	 ³
	//³ deixar fazer altaracao                                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If ( "LR_" $ ReadVar() .And. &(ReadVar()) != GDFieldGet(Replace(ReadVar(),"M->","")) ) .And. ;
		((Len(aColsDet) >= n .AND. !Empty(aColsDet[n][nPosDtReserva])) .AND. !lFtvdVer12 .OR. ;
		(Len(aColsDet) >= n .AND. !Empty(aColsDet[n][nPosDtReserva])) .AND. !lAutoExA .AND. lFtvdVer12) .AND. !lIntSynt .AND.; 
		!lIntegDef
		
		If lAutoExA  .AND. !lFtvdVer12
			Conout(STR0001 + "  " +  STR0002)
		Else
			Aviso( STR0001, STR0002, {STR0003} ) //"Aviso"###"Já existe uma reserva para esse produto, não é possível ser alterado."###"Ok"
		EndIf
		lRet := .F.

	Else

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Confirma a existencia do codigo digitado ja efetuando busca	 ³
		//³ pelo codigo de barras										 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

		If "LR_PRODUTO" $ ReadVar() .AND. nKit == 0 .AND. AllTrim(aCols[n][nPosKit]) == ""
			cProduto := &(ReadVar())
			 M->LR_VDMOST :=  "N"

			//Zera descontos em qualquer alteracao no campo LR_PRODUTO somente se a venda não for concomitante
			//pois o desconto da venda concomitante é lançado antes do produto
			If !LjAnalisaLeg(14)[1] .And. !SuperGetMV("MV_LJVACC", ,.F.) 
				aCols[n][nPosDesc]		:= 0
				aCols[n][nPosValDesc]	:= 0
			EndIf
		Else
			cProduto := aCols[n][nPosProd]
		Endif

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se contém código de lista de presentes,  ³
		//³ não trazer sugestão de vendas            ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If (nPosLPre > 0)
			nAux := aPosCpo[nPosLPre][2]
			If (nAux > 0)
				If( Len( AllTrim( aCols[n][nAux] ) ) ) > 0
					lSuVend := .F.
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Preenche com 1 caso a quantidade seja zero³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If aCols[n][nPosQuant] == 0
			aCols[n][nPosQuant] := 1
		Endif

		If cPaisLoc == "ARG" .AND. nPosProvEnt > 0
			aCols[n][nPosProvEnt] := M->LQ_PROVENT
			MaFisAlt("IT_PROVENT", aCols[n][nPosProvEnt], n)
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Relase 11.5 - Cartao Fidelidade³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lLjcFid
			//Verifica se o produto informado e de recarga de cartao fidelidade
			If LaFunhProd(cProduto)
				// Verifica se ja possui algum produto informado e nao deletado no aCols.
				If Len(aCols) > 1
					//Contar o total de produtos nao deletados (desconsiderando a ultima linha)
					For nX:=1 To Len(aCols)
						If !aCols[nX][Len(aCols[nX])] .AND. nX <> Len(aCols)
							nTotProd += 1
						EndIf
					Next nX

					//Se houver produto nao deletado, nao sera possivel incluir produto de recarga
					If nTotProd > 0
						If !lAutoExA
							Alert (STR0061)//"Este orçamento ja possui outros produtos. O produto para recarga de cartao fidelidade não poderá ser utilizado"
						Else
							Conout(STR0061)//"Este orçamento ja possui outros produtos. O produto para recarga de cartao fidelidade não poderá ser utilizado"
						EndIf
						lRet := .F.
						Return lRet
					Else
						//Se os dados informados na tela de recarga nao forem validos
						If !LaFunhInc ()
							lRet := .F.
							Return lRet
						Else
							//Atualizar vallor do produto com o valor da recarga
							aCols[n][nPosVlUnit]	:= LaFunhGet(3)
							aCols[n][nPosVlrItem]	:= LaFunhGet(3)
						EndIf
					EndIf
				Else
					//Se os dados informados na tela de recarga nao forem validos
					If !LaFunhInc ()
						lRet := .F.
						Return lRet
					Else
						//Atualizar vallor do produto com o valor da recarga
						aCols[n][nPosVlUnit]	:= LaFunhGet(3)
						aCols[n][nPosVlrItem]	:= LaFunhGet(3)
					EndIf
				EndIf
			Else
				//Contar o total de produtos nao deletados (desconsiderando a ultima linha)
				For nX:=1 To Len(aCols)
					If !aCols[nX][Len(aCols[nX])] .AND. nX <> Len(aCols)	.AND. LaFunhProd(aCols[nX][nPosProd])
						nTotProd += 1
					EndIf
				Next nX

				If nTotProd > 0
					Alert (STR0062)//"Este orçamento ja possui um produto para recarga de cartao fidelidade.Nenhum outro produto poderá ser utilizado."
					lRet := .F.
					Return lRet
				EndIf

			EndIf
		Else
			If LaFunhProd(cProduto)
				MsgStop (STR0063)//"Este produto é utilizado para recarga de cartao fidelidade e não poderá ser utilizado enquanto esta funcionalidade estiver desabilitada."
				lRet := .F.
				Return lRet
			EndIf
		EndIf

		If lRet .AND. nKit == 0 //só executa a chamada uma unica vez
			If	Posicione('SB1',1,xFilial('SB1')+cProduto,'B1_TIPO') == "KT"
				LjKitProd(@aCols,nItem,cProduto, aCols[n][nPosQuant])
				LjGrvLog("","Função Lj7Prod entrou no if de kitprod retorno da função LjKitProd= ",lRet)	
			    Return lRet
			Endif
        EndIf

		lRet := LjSB1SLK( @cProduto, @aCols[n][nPosQuant], .F., @cCodBar ) //Faz a pesquisa do codigo de produto digitado
		//Verifica se o produto tipo garantia estendida está sendo lançado no orcamento sem um produto com cobertura de garantia
		If lRet .AND. lGarantia .AND. lGE .AND. RTrim(SB1->B1_TIPO) ==  RTrim(cMvLjTGar) .AND. nGarant > 0
			//Verifica se o produto está associado
			nItGarant := Ascan(aCols, {|x| x[nGarant] == aCols[n][nPosProd]})

			If n == 1 .OR. nItGarant == 0
				If isBlind()
					ConOut( STR0001 + " "  + STR0085) //"A venda de um produto tipo garantia estendida é permitida somente amarrada a um produto com cobertura."
				Else
					Aviso( STR0001  ,STR0085, {STR0003}) //"anteção" + "A venda de um produto tipo garantia estendida é permitida somente amarrada a um produto com cobertura.""#" + "ok"
				EndIf
				lRet := .F.
			EndIf
		ElseIf lRet .AND. lSFinanc .AND. RTrim(SB1->B1_TIPO) == RTrim(cMvLjTSF)
			MG8->(dbSetOrder(2))

			//Valida se possui cadastro de servico financeiro vigente
			If MG8->(dbSeek(xFilial("MG8") + cProduto)) .AND. (dDataBase >= MG8->MG8_INIVIG .AND. dDataBase <= MG8->MG8_FIMVIG)
				If cMV_CLIPAD+cMV_LOJAPAD == M->LQ_CLIENTE+M->LQ_LOJA //Valida cliente padrao na Cxa01	venda
					Aviso(STR0001, STR0104, {STR0003}) //#"Aviso" ##"Venda de Serviço financeiro não permitida para Cliente padrão" ###"Ok"
					Return(.F.)
				ElseIf MG8->MG8_TPXPRD == "1" //Valida vinculo do produto
					If Empty(aCols[n][nPosPrdCob])
						Aviso( STR0001  ,STR0105, {STR0003}) //#"Aviso" ##"A venda de um produto tipo serviço vinculado deve ser feita na tela sugestão do produto cobertura." ###"Ok"
						Return(.F.)
					EndIf
				EndIf
			Else
				Aviso(STR0001, STR0106, {STR0003}) //#"Aviso" ##"Produto Serviço deve possuir cadastro vigente em Serviços Financeiros" ###"Ok"
				Return(.F.)
			EndIf
		ElseIf lRet .AND. lSFinanc .AND. cMV_CLIPAD+cMV_LOJAPAD == M->LQ_CLIENTE+M->LQ_LOJA .AND. lVincServ
			//Verifica se produto possui vinculo com servicos financeiros
			MBF->(dbSetOrder(4))

			//Valida se possui cadastro de servico financeiro vigente
			If MBF->(dbSeek(xFilial("MBF") + cProduto)) .AND. (dDataBase >= MBF->MBF_DTINI .AND. dDataBase <= MBF->MBF_DTFIM)
				MsgAlert(STR0107) //#"Este ítem possui vínculo com Serviços Financeiros, verifique se deseja mesmo utilizar o Cliente Padrão"

				If ExistFunc("Lj7SetServ")
					Lj7SetServ(.F.)
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Vale Presente³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lRet .And. lVPNewRegra
			If !Empty(Lj7VPYesNo())
				If Lj7VPIsPrd(cProduto)
					If Lj7VPYesNo() == "N"
						MsgStop(STR0096) //"Esta venda já possui outros produtos. O Vale Presente somente pode ser vendido individualmente."
						lRet := .F.
						Return lRet
					EndIf
				Else
					If Lj7VPYesNo() == "S"
						MsgStop(STR0097) //"Esta venda possui Vale Presente. Outros produtos não podem ser adicionados nesta mesma venda."
						lRet := .F.
						Return lRet
					EndIf
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Cartao Presente (Gift Card)  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lRet .And. lGiftCard
			lIsRecCP := Lj7CP_Prod(cProduto) //Verifica se o produto informado eh "Recarga de Cartao Presente (Gift Card)"
			If !Empty(Lj7CPGetSt())
				If lIsRecCP
					If Lj7CPGetSt() == "N"
						MsgStop(STR0101) //"Esta venda já possui outros produtos. A Recarga de Cartão Presente somente pode ser vendida individualmente."
						lRet := .F.
						Return lRet
					EndIf
				Else
					If Lj7CPGetSt() == "S"
						MsgStop(STR0102) //"Esta venda possui Recarga de Cartão Presente. Outros produtos não podem ser adicionados nesta mesma venda."
						lRet := .F.
						Return lRet
					EndIf
				EndIf
			EndIf
		EndIf

		If lRet
			//Tratamento para produto "Recarga de Celular"
			If ExistFunc("Lj7RCPrdRC")
				lIsRecCel := Lj7RCPrdRC(cProduto) //Verifica se o produto informado eh "Recarga de Celular"
			EndIf

			//Tratamento para produto "Recarga de Cartao Presente (Gift Card)"
			If lGiftCard
				If !lIsRecCP
					If "LR_PRODUTO" $ ReadVar() .AND. !Empty(GDFieldGet("LR_PRODUTO")) .And. GDFieldGet("LR_PRODUTO") <> &(ReadVar())
						If Lj7CP_Prod(GDFieldGet("LR_PRODUTO")) //Verifica se o produto informado anteriormente no mesmo item eh "Recarga de Cartao Presente (Gift Card)"
							MsgAlert(STR0092) //"Não é permitido alterar este produto, pois é um item de Recarga de Cartão Presente."
							lRet := .F.
						EndIf
					EndIf
				EndIf
			EndIf

			If lRet
				//Tratamento para produto "Recarga de Celular"
				If lIsRecCel

					If Lj7RCAtiva() //Verifica se a configuracao de "Recarga de Celular" estah ativa

						If !Lj7RCStatus()
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Tratamento para a recarga de celulares ³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							If !Lj7RCRecCel( @nVlrRecarg, cProduto, .F., (Empty(aCols[n][nPosProd]) .And. Len(aCols)==1) )
								lRet := .F.
							Else
								nPrecoTab := nVlrRecarg
								Lj7RCStatus(.T.) //Atualiza o status para "Recarga Efetuada"

								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³Acerta informacoes do aCols³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								aCols[n][nPosQuant] := 1 	//Quantidade deve ser 1

								If nPosEntrega > 0
									If ValType(aCols[n][nPosEntrega]) == "C"
										aCols[n][nPosEntrega] := " " //Limpa o campo LR_ENTREGA
									EndIf
								EndIf
							EndIf
						ElseIf Lj7RCStatus()
				       		MsgAlert(STR0082) //"Não é possível efetuar mais de uma Recarga de Celular na mesma venda."
							lRet := .F.
						Endif
					Else
						MsgAlert(STR0083) //"Este produto somente poderá ser selecionado, quando a funcionalidade de Recarga de Celular estiver devidamente configurada no sistema."
						lRet := .F.
					EndIf

				ElseIf lIsRecCP

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Tratamento para produto "Recarga de Cartao Presente (Gift Card)"³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If Lj7CP_Ativ() //Verifica se a configuracao de "Recarga de Cartao Presente (Gift Card)" estah ativa

						//Se o produto for o mesmo e for "Recarga de Cartao Presente (Gift Card)", aborta para nao fazer a recarga novamente em duplicidade
						If "LR_PRODUTO" $ ReadVar() .AND. GDFieldGet("LR_PRODUTO") == &(ReadVar())
							lRet := .F.
						Else

							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Tratamento para a "Recarga de Cartao Presente (Gift Card)" |
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							If !Lj7CP_Rcg( M->LQ_NUM, @nVlrRecarg, cProduto, .F., (Empty(aCols[n][nPosProd]) .And. Len(aCols)==1) )
								lRet := .F.
							Else
								nPrecoTab := nVlrRecarg
								Lj7CPSetSt(1) //Atualiza o status para indicar que eh "Recarga de Cartao Presente (GIFT CARD)"

								//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
								//³Acerta informacoes do aCols³
								//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
								aCols[n][nPosQuant] := 1 	//Quantidade deve ser 1

								If nPosEntrega > 0
									If ValType(aCols[n][nPosEntrega]) == "C"
										aCols[n][nPosEntrega] := " " //Limpa o campo LR_ENTREGA
									EndIf
								EndIf
							EndIf

						EndIf

					Else
						MsgAlert(STR0103) //"Este produto somente poderá ser selecionado, quando a funcionalidade de Recarga de Cartao Presente estiver devidamente configurada no sistema."
						lRet := .F.
					EndIf
				Else
					lRet := LjxeValPre (@nPrecoTab	, cProduto, M->LQ_CLIENTE, M->LQ_LOJA	,;
										nMoedaCor 	, aCols[n][nPosQuant])

					//Caso tenha passado o preco do produto (campo LR_PRCTAB), entao desconsidera o preco do produto que foi encontrado e considera o preco enviado no array da rotina automatica
					If lRet .AND. ( lIntSynt .Or. ( Type("lAutoExec") == "L" .And. lAutoExec ) )
						If nPosPrcTab > 0 .And. Len(aColsDet) >= n .AND. !Empty(aColsDet[n][nPosPrcTab]) .AND. n > 0
							nPrecoTab := aColsDet[n][nPosPrcTab] //Para Rotina automatica, considera o preco enviado no campo LR_PRCTAB
						EndIf
					EndIf

				EndIf
			EndIf
		Else
			If Empty(cProduto)
				MsgAlert(STR0056) //"Digite o código do Produto!"
			Else
				MsgAlert(STR0057) //"Produto não encontrado!"
			EndIF
		EndIf

		//#VFE
		If lLjVfe
			//Verifica se a funcionalidade de Venda Fora do estado esta ativa.
			//Acessa a tabela SB0 e busca a informação de Retira, Retira Posterior ou Entraga no campo B0_ENTREGA
			//Alimenta o aCols caso o campo não esteja vazio.
			DbSelectArea('SB0')
			DbSetOrder(1)
			If DbSeek(xFilial('SB0')+SB1->B1_COD)
				If !Empty(AllTrim(SB0->B0_ENTREGA))
					aCols[n][nPosEntrega] := SB0->B0_ENTREGA
				EndIf
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Limitacao de 10.000,00 - Legislacao Paulista 	³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lExTotalCF .AND. lExLegSP10 .AND. lRet
			If nPosEntrega > 0
				If ValType(aCols[n][nPosEntrega]) == "C"
					cEntrega := aCols[n][nPosEntrega]
				EndIf
			EndIf

			If !LjNFFimVd() .AND. LJXTpRetira(cEntrega)				  			// Se nao emitir Nota Fiscal e o produto for de Entrega = Retira ou Vazio
				nTotalCF := LJXTotalCF(n) + (nPrecoTab * aCols[n][nPosQuant])	// Obtem o total do Cupom Fiscal, considerando o item selecionado e a quantidade que ja estava no item
				lRet := Lj950SP10OK(nTotalCF, 2)								// Retona False / Sai da funcao
			EndIf
		EndIf

	    // Nesses estados nao e permitido preco zerado.
		If lRet .AND. LjAnalisaLeg(2)[1]
			//Verifica se tem Tab. de preco
			  if nPrecoTab == 0
				If !lAutoExA
					LjMsgLeg(LjAnalisaLeg(2))
					Help( " ", 1, "NOPRECO" )
				Else
					Conout(STR0073 +cProduto)		//"ATENCAO -->> PRODUTO SEM PRECO:  "
					Help( " ", 1, "Help",, STR0073 +cProduto, 1, 0 )
				EndIf
				lRet := .F.
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Deleta o item porque o produto nao tem preco. Na concomitancia ³
				//³ nao eh permitido produto sem preco                             ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lVAssConc
					aCols[n][nPosProd]   := Space(TamSX3("LR_PRODUTO")[1])
					aCols[n][nPosDescri] := Space(TamSX3("LR_DESCRI")[1])
					aCols[n][nPosQuant]  := 1
				Endif
		   	EndIf
		EndIf

		If lRet
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Se o produto for diferente do informado, 'reseta' a linha    ³
			//³ do aCols. Apenas quando nao for concomitancia                ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !lVAssConc
				If "LR_PRODUTO" $ ReadVar() .AND. gdFieldGet("LR_PRODUTO") <> &(ReadVar())
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Se for alterar um produto que ja existe no aCols faz o Backup , ³
					//³ pois se no caso desse produto nao for valido reestaurar o aCols ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				    If !Empty(gdFieldGet("LR_PRODUTO"))
						If lGE
							cMsnErro := STR0087 //Produto nao Pode ser alterado devido a Garantia Estendida. Exclua o Produto Vendido e Inclua novamente
							If !Empty(aCols[n][nGarant])
								lRet := .F.
							Else
								SB1->(DbSeek(xFilial("SB1")+aCols[n][nPosProd]))
								If SB1->B1_TIPO == cMvLjTGar
									lRet := .F.
								Else
									SB1->(DbSeek(xFilial("SB1")+cProduto))
									If SB1->B1_TIPO==cMvLjTGar
										lRet := .F.
									ElseIf SB1->B1_GARANT == "1" .And. Len(aCols)> n
										lRet := .F.
										cMsnErro := STR0089 //Produto nao Incluido devido a Garantia Estendida. Inclua na Ultima Linha
									EndIf
								EndIf
							EndIf
						EndIf

						If !lRet
							MsgAlert(cMsnErro) ////Produto nao Incluido devido a Garantia Estendida. Inclua na Ultima Linha;
							cProduto := aCols[n][nPosProd]
							nPrecoTab := aCols[n][nPosVlUnit]
							M->LR_PRODUTO := cProduto
						Else
				 	   		nBkpQuant		:=	aCols[n][nPosQuant]
					   		nBkpVlruni		:=	aCols[n][nPosVlUnit]
					  		cBkpDescri 		:=	aCols[n][nPosDescri]
					  		nBkpDesc 		:=	aCols[n][nPosDesc]
					  		nBkpValDesc		:=	aCols[n][nPosValDesc]
							cBkpUm	  		:=	aCols[n][nPosUM]
							cBkpProd   		:=	aCols[n][nPosProd]
							nBkpVlItem		:=	aCols[n][nPosVlrItem]

							If cPaisLoc == "ARG" .AND. nPosProvEnt > 0
								cBkpProvEnt		:=	aCols[n][nPosProvEnt]
							EndIf
						EndIf

			   		EndIf

					If lRet .AND. nKit == 0
						aCols[n][nPosQuant] 	:= IIf(aCols[n][nPosQuant] == 0,1,aCols[n][nPosQuant])
						aCols[n][nPosVlUnit]	:= nPrecoTab
						aCols[n][nPosDesc]		:= 0
						aCols[n][nPosValDesc]	:= 0

				    	If lTrcMoeda .AND. !lCenVenda .AND. !lIntegDef //Integracao Mensagem Unica nao altera valor unitario do produto
						   nMoedaPrv := Max(&("SB0->B0_MOEDA" + Lj7DefTab()),1)
						   aCols[n][nPosVlUnit]	:= Round(xMoeda(&("SB0->B0_PRV" + Lj7DefTab()),nMoedaPrv,nMoedaCor,dDataBase,nDecimais+1,,nTxMoeda),nDecimais)
						EndIf
					EndIf
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Grava o codigo do produto no aCols                           ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lRet
				aCols[n][nPosProd] := cProduto
	        EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica se permite vender com estoque negativo. Se a venda  ³
			//³ assistida estiver concomitante, nao deixara registrar o item ³
			//³ sem estoque.										         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lRet .AND. !lEstNeg
				If Len(aColsDet) >= n
					If ValType(aColsDet[n][nPosDtLocal]) == "U"
						cLocal := RetFldProd(SB1->B1_COD, "B1_LOCPAD")
						aColsDet[n][nPosDtLocal] := cLocal
					Else
						cLocal := aColsDet[n][nPosDtLocal]
					EndIf
				Else
					cLocal := RetFldProd(SB1->B1_COD, "B1_LOCPAD")
				Endif

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Chamada do Ponto de Entrada para personalizacao do almoxarifado da venda ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				
				If lFtvdVer12
					If lFTVD7041
						LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. FTVD7041",{cLocal,aColsDet})
						xLocal := Execblock( "FTVD7041", .F., .F., { cLocal, aColsDet } )
						LjGrvLog(M->LQ_NUM,"Depois da execução do P.E. FTVD7041",xLocal)
					EndIf
				Else				
					If lLJ7041
						LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. LJ7041",{cLocal,aColsDet})
						xLocal := Execblock( "LJ7041", .F., .F., { cLocal, aColsDet } )
						LjGrvLog(M->LQ_NUM,"Depois da execução do P.E. LJ7041",xLocal)
					Endif
				EndIf
				
				If lLJ7041 .Or. lFTVD7041
					If ValType(xLocal) == "C" .AND. !Empty(xlocal)
						cLocal := xLocal
						If ((lLJ7041 .And. lAutoExA) .Or. (lFTVD7041 .And. IsBlind())) .AND. !Empty(xLocal)
							Conout(STR0074 + "[" + Alltrim(aCols[n][nPosProd]) + Alltrim(xLocal) + "]")		//"<<<<LJ7PROD CRIASB2"
							criaSB2(aCols[n][nPosProd], xLocal)
						Endif
					Endif
				EndIf

				lValEst := Lj7VerEst( aCols[n][nPosProd], cLocal, aCols[n][nPosQuant], .T. )
			    If !lValEst .AND. (SuperGetMV("MV_LJVACC", ,.F.) .OR. lIntegDef)			    
			    	lRet := .F.
			    EndIf
			Endif

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Acerta as colunas da aCols                                   ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lRet
				If Empty( cProduto )
					cProduto := IIf(lValid, &(ReadVar()), M->LR_PRODUTO)
				EndIf
				aCols[n][nPosProd]   := cProduto

				If cPaisLoc == "ARG" .AND. nPosProvEnt > 0
					aCols[n][nPosProvEnt]   := M->LQ_PROVENT
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³SIGAPHOTO - Apenas atualiza a descricao do produto se nao vier, para nao subistituir quando for envelope.³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If nModulo == 72
					If Empty(aCols[n][nPosDescri])
						aCols[n][nPosDescri] := SB1->B1_DESC
					EndIf
				Else
					If nPosPrdCob > 0
						If Empty(aCols[n][nPosPrdCob])
							aCols[n][nPosDescri] := SB1->B1_DESC
						Else //Posiciono corretamente a descrição se for Serviço Financeiro Vinculado
							aAreaSB1 := SB1->(GetArea())
							If SB1->(DbSeek(xFilial("SB1")+aCols[n][nPosProd]))
								aCols[n][nPosDescri] :=	SB1->B1_DESC
							EndIf
							RestArea(aAreaSB1)
						EndIf
					Else
						aCols[n][nPosDescri] := SB1->B1_DESC
					EndIf
				EndIf

				aCols[n][nPosUM]     := SB1->B1_UM
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Ajusta a quantidade sempre para valor default "1". 			 ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If aCols[n][nPosQuant] == 0
				   aCols[n][nPosQuant] :=  1
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³E necessario preencher a variavel de memoria para armazenar  ³
				//³o codigo do produto e nao o codigo de barras quando utilizado|
				//|leitor de codigo de barras.                                  ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				M->LR_PRODUTO := cProduto

				If ExistBlock("LJ7061")
					LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. LJ7061")
					xRet := ExecBlock("LJ7061",.F.,.F.)
					LjGrvLog(M->LQ_NUM,"Depois da execução do P.E. LJ7061",xRet)
					If ValType( xRet ) == "L"
						lRet := xRet
					EndIf
				EndIf

				If lRet
					//Chama a tela do vale presente para a escolha do vale presente a ser vendido
					If lRet .AND. !lAutomato .AND. nPosValePre > 0 .AND. SB1->B1_VALEPRE == "1"
						cValePre := Space(TamSx3('LR_VALEPRE')[1]) 
						nValorVP := aCols[n][nPosVlUnit]
						lRet     := LjGetVlPre( M->LR_PRODUTO, @cValePre, nPosValePre, @nValorVP )
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Calcula o valor do item e verifica se ha desconto proveniente³
					//³das regras de desconto.                                      ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lRet .AND. (lCenVenda .OR. lScCsPreco)
						lRet := Lj7RegDesc(	cProduto			, lVAssConc	, @aCols		, @aHeader	,;
											aCols[n][nPosQuant]	, lBonus	, @lDescCab 	, lScCsPreco,;
											nKit)
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Calcula o valor do item 									 ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lRet .AND. !lCenVenda .AND. !lScCsPreco
						lRet := Lj7VlItem( 	Nil, Nil		, Nil		, lDescCab	,;
											Nil, Nil		, lIsRecCel	, nVlrRecarg,;
											Nil, lScCSPreco , nKit		, lIsRecCP	)
					Endif

					//Salva código de barras para utilizar na NFC-e
					If nPosCodBar > 0 .AND. !Empty(cCodBar) .AND. Len(aColsDet) >= n
						aColsDet[n][nPosCodBar] := cCodBar
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Ponto de entrada antes da impressao concomitante do item     ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lLJ7036 .AND. lRet .AND. !lFtvdVer12
						LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. LJ7036")
						lRetPE := ExecBlock( "LJ7036", .F., .F. )
						LjGrvLog(M->LQ_NUM,"Depois da execução do P.E. LJ7036",lRetPE)
						
						If ValType( lRetPE ) == "L"
							lRet := lRetPE
						EndIf

						/* Se nao aceitar a digitacao do produto, desconsidera o valor
						 que foi informano na aCols                                */
						If !lRet
							aCols[n][nPosQuant]  := 0
							aCols[n][nPosVlUnit] := 0
							aCols[n][nPosDescri] := Space( TamSx3("LR_DESCRI")[1] )
						EndIf
					EndIf
				EndIf
				
				If lRet
					If lFtvdVer12 
						If lFTVD7036
							LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. FTVD7061")
							lRetPE := ExecBlock( "FTVD7036", .F., .F. )
							LjGrvLog(M->LQ_NUM,"Depois da execução do P.E. FTVD7061",lRetPE)
							
							If ValType( lRetPE ) == "L"
								lRet := lRetPE
							EndIf
							
							/* Se nao aceitar a digitacao do produto, desconsidera o valor
								que foi informano na aCols */    
							If !lRet
								aCols[n][nPosQuant] 	:= 0
								aCols[n][nPosVlUnit]	:= 0
								aCols[n][nPosDescri]	:= Space( TamSx3("LR_DESCRI")[1] )
							EndIf
							
							lFTVD7036 := .F. //Coloco .F. para não executar novamente a validação do retorno do P.E.
						EndIf
						
						If lTFTVD7036
							LjGrvLog(M->LQ_NUM,"Antes da execução do Template Function FTVD7036")
							lRetPE := ExecTemplate( "FTVD7036", .F., .F.,{ M->LQ_NUM, M->LQ_DOC, M->LQ_SERIE, aCols[n][nItem],;
																		  cProduto	, aCols[n][nPosQuant] } )
							LjGrvLog(M->LQ_NUM,"Depois da execução do Template Function FTVD7036",lRetPE)
						EndIf
					Else
						If lTLJ7036
							LjGrvLog(M->LQ_NUM,"Antes da execução do Template Function LJ7061")
							lRetPE := ExecTemplate( "LJ7036", .F., .F.,{ M->LQ_NUM, M->LQ_DOC, M->LQ_SERIE, aCols[n][nItem],;
																		  cProduto	, aCols[n][nPosQuant] } )
							LjGrvLog(M->LQ_NUM,"Depois da execução do Template Function LJ7061",lRetPE)
						EndIf					
					EndIf
					
					If lTLJ7036 .Or. lFTVD7036 .Or. lTFTVD7036
						If ValType( lRetPE ) == "L"
							lRet := lRetPE
						EndIf
						
						/* Se nao aceitar a digitacao do produto, desconsidera o valor
							que foi informano na aCols */    
						If !lRet
							aCols[n][nPosQuant] 	:= 0
							aCols[n][nPosVlUnit]	:= 0
							aCols[n][nPosDescri]	:= Space( TamSx3("LR_DESCRI")[1] )
						EndIf
					EndIf
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Captura o codigo do vale presente, quando aplicavel			 ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If nPosValePre > 0 .AND. lRet .AND. (len(aColsDet)>=n)
					If SB1->B1_VALEPRE == "1"
						If lRet
							aColsDet[n][nPosValePre] := cValePre
							If lVPNewRegra
						        If !Empty( cValePre )
									Lj7VPVdaVP(1) //Indica que eh venda de "Vale Presente"
									If aCols[n][nPosVlUnit] <> nValorVP
										aCols[n][nPosVlUnit]	:= nValorVP		//Atribuo o valor do vale-presente
										aCols[n][nPosVlrItem]	:= A410Arred(aCols[n][nPosVlUnit] * aCols[n][nPosQuant],"LR_VLRITEM",nMoedaCor)
										Lj7VlItem(	2	,	nil,	nil,	nil,;
													nil	,	nil,	nil,	nil,;
													nil	,	nil,	nil,	nil,;
													nil	,	nil,	.T.)		//Recálculo do Preço Unitário, com o parâmetro 15 indicando Vale-Presente
									EndIf
						        EndIf
							EndIf
						EndIf
					Else
						aColsDet[n][nPosValePre] := ""
						If lVPNewRegra
				        	Lj7VPVdaVP(2) //Indica que eh venda de produto que NAO eh "Vale Presente"
						EndIf
					EndIf
				EndIf

				//Gift Card
				If lRet .And. lGiftCard .And. !lIsRecCP
					Lj7CPSetSt(2) //Atualiza o status para indicar que NAO eh "Recarga de Cartao Presente (GIFT CARD) na venda"
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Relase 11.5 - Cartao Fidelidade                                    ³
				//³Caso a funcionalidade de recarga de cartao fidelidade estiver ativa³
				//³serao informadas nas respectivas colunas do aColsDet os dados	  ³
				//³da recarga informados na tela de inclusao de saldo (LOJXFUNH)      ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lLjcFid .AND. LaFunhProd(aCols[n][nPosProd])
					//Obter numero do cartao
					If nPosNumcFi  > 0
						aColsDet[n][nPosNumcFi]:= LaFunhGet(1)
					EndIf
					//Obter data de validade do saldo
					If nPosDtsdFi  > 0
						aColsDet[n][nPosDtsdFi]:= LaFunhGet(2)
					EndIf
					//Obter valor do saldo
					If nPosVlrcFi  > 0
						aColsDet[n][nPosVlrcFi]:= LaFunhGet(3)
					EndIf
				EndIf
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Se a alteração for no LR_PRODUTO e o produto nao for valido , desconsidera o valor  ³
				//³ que foi informado no aCols e volta os campos com os dados do produto que era antes  ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If ( "LR_PRODUTO" $ ReadVar() )
					If !lRet
						aCols[n][nPosVlUnit]	:=	nBkpVlruni
						aCols[n][nPosQuant]		:=	nBkpQuant
			 		   	aCols[n][nPosDescri]	:=	cBkpDescri
			 		   	aCols[n][nPosDesc]		:=  nBkpDesc
						aCols[n][nPosValDesc]	:=  nBkpValDesc
						aCols[n][nPosUM]		:=  cBkpUm
						aCols[n][nPosProd]    	:=  cBkpProd
						ACols[n][nPosVlrItem]	:=	nBkpVlItem

						If cPaisLoc == "ARG" .AND. nPosProvEnt > 0
							aCols[n][nPosProvEnt]  	:=  cBkpProvEnt
						EndIf
					Else
						//Se o produto alterado era produto de "Recarga de Celular", cancela transacao TEF referente a Recarga de Celular
						If ExistFunc("Lj7RCAtiva") .And. Lj7RCAtiva() .And. !Empty(cBkpProd) .And. Lj7RCPrdRC(cBkpProd)
							If Lj7RCStatus()
								Lj7RCStatus(.F.) //Atualiza o status para "Recarga NAO efetuada"
								oTef:FinalTrn(0) //Envia o desfazimento da transacao TEF
							Endif
						ElseIf lGiftCard .And. Lj7CP_Ativ() .And. !Empty(cBkpProd) .And. Lj7CP_Prod(cBkpProd)
							//Se o produto alterado era produto de "Recarga de Cartao Presente (Gift Card)", cancela transacao TEF referente a Recarga
							If Lj7CPGetSt()=="S"
								Lj7CPSetSt(0) //Atualiza o status para "Recarga NAO efetuada"
								oTef:FinalTrn(0) //Envia o desfazimento da transacao TEF
							Endif
						EndIf
					EndIf
	            EndIf
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Venda assistida Concomitante. Faz a impressao do item no ECF ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				//PAF: lVAssConc é ativada quando Retaguarda PAF-ECF para realizar diversas validacoes, porem, nao deve passar nesse ponto quando Retaguarda PAF-ECF.
				If !lEmitNFCe .And. !lIsPafNfce
					If lVAssConc .AND. lRet .AND. !lRetaPaf
		    			If !HasTemplate("DRO") .And. (!lVPNewRegra .Or. Empty(cValePre)) .And. (!lGiftCard .Or. Lj7CPGetSt()!="S")
		    				LJ7ImpItCC( n , , , , , ,n )
		    			EndIf
		    		ElseIf ExistFunc("LJHOMTEF") .AND. LJMSSM0(SM0->M0_CGC)
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³ Nao concomitante abre o cupom fiscal                         ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						nRet := IFStatus( nHdlECF, '5', @cRetorno )
						If LjAnalisaLeg(42)[1]
							If !LjCxAberto(.T.,xNumCaixa())
								nRet := 1
							Else
								nRet := IFAbreCup(nHdlECF ,Nil ,Nil ,Nil ,.F. )
							EndIf
						Else
							nRet := IFAbreCup(nHdlECF,Nil ,Nil, Nil ,.F.)
						EndIf
					EndIf
				EndIf

			Endif
		EndIf
	Endif

	If lRet .AND. (((SB1->( ColumnPos("B1_DESCONT")) > 0)  .AND. (SB1->B1_DESCONT > 0))  .OR. lLJ8099)

		If lLJ8099
			LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. LJ8099")
			M->LR_DESC	:= Execblock( "LJ8099", .F., .F. )
			LjGrvLog(M->LQ_NUM,"Antes da execução do P.E. LJ8099",M->LR_DESC)
	 	Else
	 		M->LR_DESC	:= SB1->B1_DESCONT
	 	EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Valida se o desconto está correto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	 	If  !lj7VlItem(3, Nil, Nil, Nil, Nil, M->LR_DESC, Nil, Nil, Nil, lScCsPreco)
			If !lAutoExA
				Alert(STR0071)    //"Nao foi possivel realizar desconto cadastrado no produto e sera zerado."
			Else
				Conout(STR0071)   //"Nao foi possivel realizar desconto cadastrado no produto e sera zerado."
			EndIf
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Cria loker para carga nova³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lRet
		If( ExistFunc("LOJA0051") .And. SuperGetMV( "MV_LJILVLO",,"2" ) == "1", oLJCLocker:GetLock( "LOJA701AILLock" ), .T. )
			If lSuVend .AND. ( nModulo == 12 .OR. nModulo == 23 .OR. nModulo == 72 .OR. lFtvdVer12 ) .AND.  ExistFunc("Lj7SugVend")
				#IFDEF TOP
	 				Lj7SugVend(Nil,lSugestao,cProduto)
				#ENDIF
			EndIf
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Valida se o produto tem Garantia Estendida e Chama a Função principal de Garantia LOJXFUNG³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If !lAutoExec .AND. lRet	//Não chamar se for SigaFat
			If lGE .AND. lGarantia .AND. (SB1->B1_GARANT == "1") .AND. ExistFunc("Lj7GarEst") .And. lLJ7081    // Parametro lLJ7081 para Habilitar a Garantia Estendida
				If (nModulo == 5)	//Chamo o aviso de não permitido uma única vez
					Lj7GeMod5()
				ElseIf (cMV_CLIPAD+cMV_LOJAPAD) <> (M->LQ_CLIENTE+M->LQ_LOJA) .And. Empty(aCols[n][nGarant])
	
					If Len(aCols) == n
						Lj7GarEst(Nil,Nil,cProduto,aCols[n][nPosVlUnit])
					Else
				    	MsgAlert(STR0088)//Não pode ser incluida a Garantia Estendida. Caso queira Incluir a Garantia Estendida, Exclua e Inclua novamente o Produto
					EndIf
				EndIf
			ElseIf lSFinanc .AND. SB0->(ColumnPos("B0_SERVFIN")) > 0 .AND. SB0->B0_SERVFIN = "1"
				If (nModulo == 5)	//Chamo o aviso de não permitido uma única vez
					Lj7GeMod5()
				ElseIf (cMV_CLIPAD+cMV_LOJAPAD) <> (M->LQ_CLIENTE+M->LQ_LOJA)
					//Chama a Funcao principal para Servicos Financeiros
					Lj7GarEst(Nil,Nil,cProduto,aCols[n][nPosVlUnit])
				EndIf
			EndIf
		EndIf
	EndIf


//Valida se a margem esta aceitavel.
If lMargem .AND. lRet
	If Lj701MgV(n)
		If MsgYesNo(STR0094)//"O produto esta fora da margem de preço cadastrada. Deseja continuar ?"
			If !LjProfile(35)
				Lj7ValDel(, ,  , ,.T.)
				If Len(aColsDet) >= n
				   aColsDet[n][Len(aColsDet[n])] 	:= .T.
				EndIf
				aColsDet[n][Len( aHeaderDet )+1]	:= .T.
				aCols[n][Len( aHeader )+1]	:= .T.
			EndIf
		Else
			Lj7ValDel(, ,  , ,.T.)
			If Len(aColsDet) >= n
			   aColsDet[n][Len(aColsDet[n])] 	:= .T.
			EndIf
			aColsDet[n][Len( aHeaderDet )+1]	:= .T.
			aCols[n][Len( aHeader )+1]	:= .T.
		EndIf
	EndIf
EndIf

If lRet .And. nPosClasFis > 0 .And. (nPosClasFis := aPosCpo[nPosClasFis][2] ) > 0
	aCols[n][nPosClasFis] := iIf(ExistFunc("Lj7RetClasFis"), Lj7RetClasFis(/*cProd*/, /*cTes*/, /*cNumLote*/, /*cLoteCtl*/,/*nItens*/n), Space(TamSx3("LR_CLASFIS")[1]))
EndIf

//Integracao Mensagem Unica nao carrega Reducao de Base pois ja informado no xml
If !lIntegDef
	If nPosPRedIc > 0 .And. n > 0 .And. MaFisFound("NF") .And. MaFisFound("IT",n)
		aCols[n][nPosPRedIc]  :=  MaFisRet(n,"IT_PREDIC")// %Redução da Base do ICMS
	EndIf
EndIf

//Como o UPDLOJ09 se tornou obsoleto, executamos a funcao que estava no X3_VALID do campo LR_PRODUTO,
// para verificar se o produto possui acessorios cadastrados (Kit de Produtos)
//Adicionada validacao lItemKit para chamar apenas para produto pai
LjGrvLog("","Função Lj7Prod MV_LOJKIT ",SuperGetMV("MV_LOJKIT",,.F.))
If SuperGetMV("MV_LOJKIT",,.F.) .AND. !lItemKit
	LjInfoKit()
EndIf

if ((Type("lAutoExec") == "L" .And. !lAutoExec) .Or.;
	(Type("lAutoExec") <> "L"))	.And.;
 	lRet .AND.  aCols[N][nPosProd] <> cBkpProd
 	
	If nPosNSerie > 0
		aCols[N][nPosNSerie] := Nil
	EndIf
	aColsDet[N][nPosLocaliz] := Space(TamSX3("LR_LOCALIZ")[1])
	aColsDet[N][nNSerieDet]  := Nil
	aColsDet[N][nPosDtValid] := cToD("")
	aColsDet[N][nPosSubLote] := Space(TamSX3("LR_NLOTE")[1])
EndIf 

RestArea(aArea)		// Restaura area anterior

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjVl7Item  ºAutor  ³ Vendas Clientes    º Data ³  04/07/05  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Calcula o Valor do Item                                    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±º          ³ ExpN1:  Indica qual campo chamou esta funcao               º±±
±±º          ³ 0 - Chamado a partir de um fonte							  º±±
±±º          ³ 1 - Foi chamada a partir do X3_VALID do campo LR_QUANT     º±±
±±º          ³ 2 - Foi chamada a partir do X3_VALID do campo LR_VRUNIT	  º±±
±±º          ³ 3 - Foi chamada a partir do X3_VALID do campo LR_DESC      º±±
±±º          ³ 4 - Foi chamada a partir do X3_VALID do campo LR_VALDESC   º±±
±±º          ³ 5 - Chamado a partir de um Gatilho                         º±±
±±º          ³ 6 - Foi chamada a partir do X3_VALID do campo LR_PROVENT   º±±
±±º          ³ ExpL2:  Indica se houve desconto pela regra de desconto    º±±
±±º          ³ ExpL4:  Indica se houve desconto pela reg. desc. no total  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7VlItem( nField		, lRegrDesc	, lBonus	, lDescCab	,;
					lCalcDesc	, nValDes	, lIsRecCel	, nVlrRecarg,;
					lAlterProd 	, lScCsPreco, nKit 		, lIsRecCP	,;
					lReproVlIt  , lZeraPgto , lValePre 	, lAplRgDesT )
Local aArea			:= GetArea()																		// Armazena area atual (alias, order e recno)
Local nPosItem 		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})][2]				// Posicao da coluna Item
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]			// Posicao da codigo do produto
Local nPosDescri	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESCRI"})][2]			// Posicao da descricao do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]				// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]				// Posicao do Valor unitario do item
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]			// Posicao do Valor do item
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]				// Posicao do percentual de desconto
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]			// Posicao do valor de desconto
Local nPosProvEnt	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PROVENT"})						// Posicao da provincia de entrega
Local nPosValGar	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_GARANT"})						// Posicao do Campo Garantia
Local nPosDtVldProd := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VLGAPRO"})					// Posicao do Campo Qtde dias validade da garantia do produto
Local nPosPrcTab	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})						// Posicao do Preco de Tabela
Local nPosDtDProp	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO"})						// Posicao do Desconto proporcional
Local nPosDtReserva	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_RESERVA"})						// Posicao do codigo da reserva
Local nPosDtLocal  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCAL"})						// Posicao do local (armazem)
Local nPosLoteCtl	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL"})						// Posicao do lote do produto
Local nPosSubLote	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE"})						// Posicao do sublote do produto
Local nPosLegCod	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_LEGCOD"})		   					// Posicao do Codigo do Abastecimento(TPL Posto -> Tabela LEG)
Local nTamB8_NUMLOTE:= TamSx3("B8_NUMLOTE")[1]															// Tamanho do campo B8_NUMLOTE
Local nTamB8_LOTECTL:= TamSx3("B8_LOTECTL")[1]															// Tamanho do campo B8_LOTECTL
Local nVlUnit 		:= 0																				// Valor unitario do produto (conf. tabela)
Local nQuant 		:= 0																				// Quantidade do produto
Local nAuxTotal		:= 0																				// Auxiliar para calculo do subtotal e total
Local nAuxQuant		:= 0																				// Auxiliar para calculo da quantidade total - Gorgulho
Local nVlrDesc		:= 0																				// Auxiliar para calculo do valor do desconto
Local nVlrPDesc		:= 0																				// Auxiliar para calculo do valor do percentual do desconto
Local nValUnitAnt   := 0                                												// Valor Unitario atual
Local lEstNeg 		:= ( SuperGetMV("MV_ESTNEG",,"S") == "S" ) .OR. lMVLJPDVPA							// Indica se permite vender com estoque negativo
Local lTrcMoeda     := SuperGetMV("MV_TRCMOED",,.T.)													// Indica se permite escolha de moeda
Local cFormDesc  	:= SuperGetMV("MV_LJFORMD",.F.,"1" ) 												// Tipo de validacao do desconto (valor ou % / valor e %)
Local aDesc			:= {"V", 0}																			// Array com o Desconto
Local nDescP		:= 0																				// Utilizada para validacao do Percentual do Desconto
Local nDescV		:= 0																				// Utilizada para validacao do Valor do Desconto
Local cLocal 		:= ""                               												// Armazena o local padrao
Local nAuxPrItem    := 0	                               												// Valor do percentual (para o calculo do desconto)
Local nMoedaPrv     := 1   	                            												// Moeda da tabela de preco selecionada
Local nX            := 0	                               												// Variav. usada em lacos For...Next
Local cProd_cpo0    := ""                               												// Produto digitado 			Venda assistida concomitante
Local nQtd_cpo1     := 0      																			// Quantidade digitada          Venda assistida concomitante
Local nVlUn_cpo2    := 0																				// Valor unitario do Item
Local nVlPd_cpo3    := 0                                												// Percentual desconto digitado  Venda assistida concomitante
Local nVDes_cpo4    := 0                                												// Valor desconto digitado       Venda assistida concomitante
Local lVAssConc     := LjVassConc()																		// Indica se o cliente utiliza a Vda Assistida Concomitante
Local aTamL2DESC	:= TamSx3("L2_DESC")																// Array com os dados do campo L2_DESC
Local lAlterPre 	:= .F.																				// Se permite alteracao de preco
Local oDesconto																							// Instancia o objeto que fara o desconto
Local nMvLjTpDes	:= SuperGetMv( "MV_LJTPDES", , 0 )													// Indica qual desconto sera' utilizado 0 - Antigo / 1 - Novo (objeto)
Local cRastro  		:= SuperGetMV("MV_RASTRO")															// Verifica se a rastreabilidade esta' habilitada
Local nValorItem	:= 0																				// Valor do item que sera utilizado no calculo do desconto se MV_LJTPDES = 1
Local aDescBkp		:= {}																				// Armazena a linha do item atual antes de conceder descontos
Local lPcMult       := .F.																				// Verifica se o Produto digitado na consulta existe.
Local aColsTmp		:= {}																				// Acols temporario utilizado pela regra de descontos
Local nPosDtMont	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_FDTMONT"})
Local nPosDtEntr	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_FDTENTR"})
Local nTotal		:= 0																				// Total da venda sem descontos
Local nValDscIt		:= 0																				// Valor total de descontos nos itens
Local nPosDelet		:= Len(aHeader)+1																	// Posicao do controle de delecao de linha
Local nRegDesc		:= 0																				// Desconto proveniente da regra
Local nPrecoTab		:= 0																				// Variavel para armazenar o preco da tabela
Local nBKP			:= 0																				// Backup da variavel n
Local lRecalcIt		:= .F.																				// Controla se deve recalcular os itens apos alteracao no desconto no item e zerar o desconto total
Local nPosaCols     := n                                                                                // Bkp da linha possicionada no acols
Local nBkDesc  		:= aCols[n][nPosValDesc]																// Backup de valor antes de digitar
Local nBkPrcTab		:= 0																				// Backup do valor do produto
Local nTotalCF		:= 0																				// Valor total do cupom fiscal (diferente do total da nota)
Local nPosEntrega	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ENTREGA"})][2]			// Posicao da Unidade de Medida
Local cEntrega		:= ""																				// Tipo de entrega do item
Local lExLegSP10	:= .T.																				// Verifica a existencia da funcao que valida a legislacao paulista que limita o cupom fiscal em 10.000,00
Local lExTotalCF	:= .T.																				// Verifica a existencia da funcao que calcula o total do cupom fiscal
Local lAutoExA		:= IsBlind()																		// Verifica se a rotina sera executada via execauto ou nao
Local lItemAbast	:= .F.																				// Sinaliza se item de abastecimento
Local nVlItem		:= 0																				// Valor do Item
Local lStatusImp13 	:= .F.																				// Status 13 do ECF. Indica se o ECF arredonda (.T.) ou trunca (.F.) o valor total
Local nSuframa      := 0                                                                                // Variavel para armazenar o valor de suframa
Local nY            := 0                                                                                // Variavel auxiliar usada em lacos For...Next
Local cCodPrdAux 	:= ""																				// Variavel auxiliar para armazenar o Codigo do Produto
Local lMvAjstDes	:= SuperGetMV("MV_LJAJDES", Nil, .F.)												// verifica se o parametro de ajuste de desconto esta ativo
Local lGE			:= ExistFunc("LjUP104OK") .AND. LjUP104OK()										// Validação do Conceito Garantia Estendida
Local nPosDtLojaRes	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_LOJARES"})			  			// Posicao do codigo da reserva - Garantia Estendida
Local nGarant	    := 0
Local lLjcFid 		:= SuperGetMv("MV_LJCFID",,.F.) .AND. CrdxInt()							//Indica se a recarga de cartao fidelidade esta ativa
Local lMargem       := SuperGetMV("MV_LJMARGE",,.F.) 				            // Valida se considera a margem minIma no venda assistida.
Local nDiasGar		:= 0																				// Dias de Garantia
Local lECommerce	:= SuperGetMV("MV_LJECOMM",,.F.) .AND.  ( SL1->((ColumnPos("L1_ECFLAG") > 0) .AND. (L1_ECFLAG == "1"))  .OR. (ExistFunc("LJ862ECAuto") .And. LJ862ECAuto()) )
Local lMvLjIPEn	 	:= SuperGetMV("MV_LJIPENP",, .F.)
Local cCondBkp		:= "" //Backup da Condicao de Pagamento
Local lLJ8099		:= ExistBlock("LJ8099")   // Garantia Estendida	Ponto de entrada pra habilitar a Garantia Estendida Default .T.
Local lValidCpo		:= .T.		// controle para verificacao na funcao estoque do loja Lj7SaldoBF
Local lIntSynt 	 	:= SuperGetMV("MV_LJSYNT",,"0") == "1"	 // Informa se a integracao Synthesis esta ativa
Local lRet			:= .F.
Local lECCia 		:= SuperGetMV("MV_LJECOMM",,.F.) .AND. SuperGetMV("MV_LJECOMO",,.F.) .AND.  (SL1->(L1_ECFLAG == "1") .OR.  Lj901Auto() )
Local nVlrIcmSol	:= 0
Local nPosDescPro   := aScan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO"}) // Posicao do Desconto Proporcional
Local nVlrItem      := 0
Local aPgtoEx		:= {}	//Excessão de forma de pagamento quando executar a rotina Lj7ZeraPgtos 
Local lIntegDef		:= IsBlind() .And. FWHasEAI("LOJA701",, .T., .T.) .AND. IIF( ExistFunc("Lj701GtInD") , Lj701GtInD(), IsInCallStack("LOJI701"))  //Integracao via Mensagem Unica
Local lValEst		:= .T. //Validacao de estoque integracao
Local aVidaLink		:= LJGDadosVL()		//Dados do PBM Funcional Card
Local nPosPBM		:= 0				//Posição encontrada da busca do produto para exclusão
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local lPBMDesc		:= ExistTemplate("DroPbmDe") .AND. T_DroPbmDe()
Local nPosCodBar	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CODBAR"})						// Posicao do sublote do produto
Local nPosKit       := Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_KIT"})	//Posicao do parametro KIT
Local lKit 			:= .F. 

Default nField 		:= 0
Default lRegrDesc	:= .F.			// Indica se a funcao foi acionada para preenchimento de desconto por regra
Default lBonus		:= .F.			// Define se o item se refere a bonificacao
Default lDescCab    := .F.  		// Indica se houve desconto pela regra de desconto no total da venda
Default lCalcDesc	:= .F.			// Controla se deve utiliza a variavel de memoria para calcular o desconto ou o aCols
Default nValDes		:= 0            // valida desconto
Default lIsRecCel 	:= .F.			// Indica que eh produto "Recarga de Celular"
Default nVlrRecarg 	:= 0			// Valor da "Recarga de Celular" ou da "Recarga de Cartao Presente (Gift Card)"
Default lAlterProd	:= .F.
Default lScCsPreco	:= .F.			// Indica se a consulta de preco via WS esta habilitada
Default nKit        := 0
Default lIsRecCP 	:= .F.	  		// Indica que eh produto "Recarga de Cartao Presente (Gift Card)"
Default lReproVlIt 	:= .F.
Default lZeraPgto	:= .T. 
Default lValePre	:= .F.
Default lAplRgDesT	:= .F.			// Indica se respeita a regra de desconto no Total para poder zerar as variáveis

LjGrvLog(M->LQ_NUM," nModulo que esta sendo acessado ?", nModulo)
LjGrvLog(M->LQ_NUM," É do Venda Direta ?", lFtvdVer12)

If lGE
	lRet := Lj7VlField()
	If !lRet
		Conout(M->LQ_NUM + " - " +STR0115)
	    LjGrvLog(M->LQ_NUM, STR0115) //"Saiu após executar Lj7VlField()"
		Return lRet
	EndIf

	If Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"}) > 0
		nGarant	    := aPosCpo[Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_GARANT"})][2]	// Posicao do valor da garantia
	EndIf
EndIf

// Validação para Kit de Produtos
If ExistFunc("Lj7IsKit") .And. nField <> 0 .And. !IsInCallStack("LJNFCELOT") //Quando Finalização de NFCE em Lote, a validação de KIT não deve ser executada neste ponto. Pois a mesma e executada via rotina automatica.
	If Lj7IsKit(aCols[n][nPosItem], aCols[n][nPosProd])
		If aCols[n][nPosVlUnit] > 0		
			lRet := Lj7VlField("GET")
			If !lRet
				Return lRet
			EndIf
		EndIf 
	EndIf
EndIf

/*Inserida chamada da funcao Lj7VldUs, para que seja controlado
  nos campos 1 = LR_QUANT, 2 = LR_VRUNIT , 3 = LR_DESC, e    
		4 = LR_VALDESC a integridade de vendedor/usuario 		*/
If (nField == 1) .OR. (nField == 2) .OR. (nField == 3) .OR. (nField == 4)
	If !Lj7VldUs()
	    LjGrvLog(M->LQ_NUM, STR0116)//"Saiu após executar Lj7VldUs()"
   		lRet := .F.
		Return lRet
	EndIf
EndIf

If cPaisLoc == "ARG" .AND. nField == 6
	If nPosProvEnt > 0
		nPosProvEnt	:= aPosCpo[nPosProvEnt][2]
		aCols[n][nPosProvEnt] := M->LR_PROVENT
		MaFisAlt("IT_PROVENT", aCols[n][nPosProvEnt], n)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Altera variavel private para desconto³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nValDes > 0
	__ReadVar := "M->LR_DESC"
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Caso a Consulta Multimida esteja ativada nao vai usar ³
//³essa funcao.                                          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If HasTemplate("DRO")
	If T_DroSendPCM()
		lPcMult :=  ExistCPO("SB1",M->LR_PRODUTO,1) 
		LjGrvLog(M->LQ_NUM, STR0117)//"Saiu após executar  T_DroSendPCM()"
		Return lPcMult
	EndIf
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Limitacao de 10.000,00 - Legislacao Paulista 	³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If nField == 1 .And. lExTotalCF .AND. lExLegSP10	 // Se o campo for [Quantidade]
	If nPosEntrega > 0
		If ValType(aCols[n][nPosEntrega]) == "C"
			cEntrega := aCols[n][nPosEntrega]
		EndIf
	EndIf

	If !LjNFFimVd() .AND. LJXTpRetira(cEntrega)  							// Se nao emitir Nota Fiscal e o produto for de Entrega = Retira ou Vazio
		nTotalCF := LJXTotalCF(n) + (aCols[n][nPosVlUnit] * M->LR_QUANT) 	// Obtem o total do Cupom Fiscal, considerando o item selecionado e sua quantidade digitada
		If !Lj950SP10OK(nTotalCF, 2)  										// Analisa se ultrapassou o limite da legislacao / [Deseja continuar? = NAO]. [Flag = 2 -> Indica que fara a pergunta se deseja continuar, caso ultrapasse o limite da legislacao]
			Lj7T_Total(2, Lj7T_Subtotal(2))
			LjGrvLog(SL1->L1_NUM, STR0118,nTotalCF) //"Total da Venda ultrapassa o permitido"									// Atualiza os totais da venda
			Return .F.					 	   								// Retona False / Sai da funcao
		EndIf
	EndIf
EndIf

If ReadVar() $ "M->LR_PRODUTO|M->LQ_PRODUTO"
	If nPosDtMont > 0
		M->LR_FDTMONT 			:= Lj7PegaMontagem( &( ReadVar() ) )
		aCols[n][nPosDtMont] 	:= M->LR_FDTMONT
	EndIf
	If nPosDtEntr > 0
		M->LR_FDTENTR 			:= Lj7PegaEntrega( &( ReadVar() ) )
		aCols[n][nPosDtEntr] 	:= M->LR_FDTENTR
	EndIf
	If lFtvdVer12
		cTES := Posicione("SB1",1,xFilial("SB1") + &( ReadVar() ),"SB1->B1_TS")
		If !Empty(cTES)
			cTES := Posicione("SF4",1,xFilial("SF4") + cTES,"SF4->F4_CODIGO")
			If !RegistroOk("SF4")
			    LjGrvLog(M->LQ_NUM, STR0119 + SB1->B1_COD,cTES) //"Problemas no cadastro da TES: Produto: "
				return .F.
			EndIf
		EndIf
	EndIf
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Se chamada pelo valid do LR_DESC ou LR_VALDESC e o    ³
//³valor atual e o anterior for igual a zero retorna .T. ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( nField == 3 .OR. nField == 4 ) .AND. M->LR_DESC == 0 .AND. M->LR_VALDESC == 0 .AND.;
		aCols[n][nPosDesc] == 0 .AND. aCols[n][nPosValDesc] == 0 .AND. !lCalcDesc
	Return .T.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao permitir alterar um item deletado     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( nField < 5 ) .AND. aCols[n][Len(aCols[n])]
	If !lAutoExA
		MsgStop(STR0058)		// "Não é permitido modificar um item deletado."
	Else
		Conout(STR0058)		// "Não é permitido modificar um item deletado."
	EndIf
	LjGrvLog(M->LQ_NUM, STR0058) //// "Não é permitido modificar um item deletado."
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao permite valor negativo no campo quantidade quando nao ha concomitancia     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nField == 1 .And. ReadVar() == "M->LR_QUANT"
	If  M->LR_QUANT <= 0
		If !lAutoExA
			MsgStop(STR0038) // Valor nao permitido para esse campo.
		Else
		    Conout(STR0038) //Valor nao permitido para esse campo.
		EndIf
		LjGrvLog(SL1->L1_NUM, STR0038 + " LR_QUANT " ,M->LR_QUANT) 
		Return .F.
	ELse
		If !lIntegDef .And. !Lj7SaldoBF(lValidCpo) // nvalid == 1 ,
		    LjGrvLog(SL1->L1_NUM, STR0120) //"Saiu ao executar a rotina Lj7SaldoBF()"
			Return .F.
		EndIf
	EndIf
EndIf

//Verifica se o produto eh "Recarga de Celular" ou "Recarga de Cartao Presente" (Gift Card)
If (ExistFunc("Lj7RCAtiva") .And. Lj7RCAtiva()) .Or. (ExistFunc("Lj7CP_OK") .And. Lj7CP_OK() .And. Lj7CP_Ativ())
	If ReadVar() = "M->LR_PRODUTO"
		cCodPrdAux := &(ReadVar())
	Else
		cCodPrdAux := aCols[n][nPosProd]
	EndIf
	If !Empty(cCodPrdAux)
		lIsRecCel := Lj7RCPrdRC(cCodPrdAux)
		If lIsRecCel
			If ReadVar() $ "M->LR_QUANT|M->LR_DESC|M->LR_VALDESC"
				MsgAlert(STR0086) //"Não é permitido alterar este campo devido ser produto Recarga de Celular."
				LjGrvLog(SL1->L1_NUM, STR0086 + " M->LR_QUANT|M->LR_DESC|M->LR_VALDESC")//"Não é permitido alterar este campo devido ser produto Recarga de Celular."
				Return .F.
			Else
				aCols[n][nPosVlUnit] := nVlrRecarg
			EndIf
		EndIf

		lIsRecCP := If(ExistFunc("Lj7CP_Prod"),Lj7CP_Prod(cCodPrdAux),.F.)
		If lIsRecCP
			If ReadVar() $ "M->LR_QUANT|M->LR_DESC|M->LR_VALDESC"
				If ReadVar() $ "M->LR_QUANT"
					MsgAlert(STR0093) //"Não é permitido alterar este campo devido ser produto Recarga de Cartão Presente."
					LjGrvLog(SL1->L1_NUM, STR0093 ,"M->LR_QUANT") //"Não é permitido alterar este campo devido ser produto Recarga de Cartão Presente."
					Return .F.
				EndIf
			Else
				aCols[n][nPosVlUnit] := nVlrRecarg
			EndIf
		EndIf

	EndIf
EndIf

If cPaisLoc == "ARG"
	If Empty(aCols[n][nPosProd])
		If !lAutoExA
			MsgInfo(STR0059)	// "Ingrese el codigo de producto."
		Else
			Conout(STR0059)	// "Ingrese el codigo de producto."
		EndIf
		Return .F.
	EndIf

	If nField == 2
		nBkPrcTab := aColsDet[n][nPosPrcTab]
		aColsDet[n][nPosPrcTab] := &(ReadVar())
	ElseIf nField <> 0
		aCols[n][nPosVlUnit] := aColsDet[n][nPosPrcTab]
	EndIf
EndIf

If cPaisLoc <> "BRA" .AND. Lj7T_DescV(2) > 0
	If nRotina == 4 .AND. nField <> 5
		lRecalcIt := .T.
	EndIf
	//Verifica se foi alterado o valor do desconto no item da venda
	If ReadVar() $ "M->LR_QUANT|M->LR_PRODUTO|M->LR_DESC|M->LR_VALDESC" .And. MafisFound()
		Lj7LimpDes()
	EndIf
	Lj7T_DescV(2, 0)
	Lj7T_DescP(2, 0)
EndIf

If lMargem .AND. (nField == 3 .OR. nField == 4) .AND. (M->LR_DESC > 0 .OR. M->LR_VALDESC > 0 )
	//Valida se a margem esta aceitavel.
	nVlrItem := aCols[n][nPosVlItem] + aColsDet[n][nPosDescPro] + aCols[n][nPosValDesc] //Valor original do item na venda
	If Lj701MgV(n,, Iif(M->LR_DESC > 0,Round( (M->LR_DESC * nVlrItem) / 100, nDecimais ) , M->LR_VALDESC ) )
		If MsgYesNo(STR0094)//"O produto esta fora da margem de preço cadastrada. Deseja continuar ?"
			If !LjProfile(35)
			    LjGrvLog(SL1->L1_NUM, STR0094)//"O produto esta fora da margem de preço cadastrada. Deseja continuar ?"
				Return .F.
			EndIf
		Else 
		    LjGrvLog(SL1->L1_NUM, STR0094) //"O produto esta fora da margem de preço cadastrada. Deseja continuar ?"
			Return .F.
		EndIf
	EndIf
EndIf


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Caso o parametro esteja com 1, inicializa o objeto de ³
//³desconto.                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nMvLjTpDes == 1 .OR. nMvLjTpDes == 2
	oDesconto := Desconto():New()
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se nao for concomitante pego o valor a Variavel que acabou de receber a digitacao da quantidade          ³
//³ Se For Concomitante, entao pega o valor do Acols que recebeu a digitacao  								 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Relase 11.5 - Cartao Fidelidade 						 ³
//³Se chamada pelo valid do LR_QUANT e o produto for     ³
//³recarga de cartao de fidelidade, nao permite alterar o³
//³o valor atual que sera sempre 1						 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If  nField == 1 .AND. (LaFunhProd(aCols[n][nPosProd])) .AND. (M->LR_QUANT <> 1)
	If !lAutoExA
		MsgStop(STR0064)	// "A quantidade do produto para recarga de cartao fidelidade nao deve ser diferente de 1"
	Else
		Conout(STR0064)	// "A quantidade do produto para recarga de cartao fidelidade nao deve ser diferente de 1"
	EndIf
	LjGrvLog(SL1->L1_NUM, STR0064 ,M->LR_QUANT)//"A quantidade do produto para recarga de cartao fidelidade nao deve ser diferente de 1"
	Return .F.
EndIf

If lVAssConc
   cProd_cpo0 := Iif( lVAssConc .AND. nField==0, IiF( "LR_PRODUTO" $ ReadVar(),M->LR_PRODUTO,"") , gdFieldGet("LR_PRODUTO"))
   nQtd_cpo1  := Iif( lVAssConc .AND. nField==0, gdFieldGet("LR_QUANT")  , IiF( "LR_QUANT" $ ReadVar(),M->LR_QUANT,0      ))
   nVlUn_cpo2 := Iif( lVAssConc .AND. nField==0, gdFieldGet("LR_VRUNIT") , IiF( "LR_VRUNIT" $ ReadVar(),M->LR_VRUNIT,0    ))
   nVlPd_cpo3 := Iif( lVAssConc .AND. nField==0, gdFieldGet("LR_DESC")   , IiF( "LR_DESC" $ ReadVar(),M->LR_DESC,0        ))
   nVDes_cpo4 := Iif( lVAssConc .AND. nField==0, gdFieldGet("LR_VALDESC"), IiF( "LR_VALDESC" $ ReadVar(),M->LR_VALDESC,0  ))
Endif

lAlterPre := IIF(lAutoExA,.T.,LjCanAtuPr(SM0->M0_CGC)) .OR. lValePre

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Conforme legislacao, em alguns estados nao poderah alterar o valor do Produto. ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nField == 2 .AND. !lAlterPre .AND. cPaisLoc == "BRA"  .And. !IsInCallStack("LJNFCELOT") //Quando Finalização de NFCE em Lote, a validação ja foi efetuada, quando salvo orçamento anteriormente.
    LjGrvLog(SL1->L1_NUM, STR0126)//"Conforme legislação não pode alterar o produto"
	Return .F.
EndIf

If lCenVenda .And. !lIntegDef //Integracao nao valida regra de desconto
	If (nField == 3 .OR. nField == 4) .AND. !lRegrDesc .AND. !LjOpcDesc()
		If !lAutoExA
			MsgStop(STR0053) //"Não é permitido alterar o desconto atribuido pela regra de descontos, conforme a configuração do caixa atual."
		Else
			ConOut(STR0053) //"Não é permitido alterar o desconto atribuido pela regra de descontos, conforme a configuração do caixa atual."
		EndIf
		LjGrvLog(SL1->L1_NUM, STR0053)//"Não é permitido alterar o desconto atribuido pela regra de descontos, conforme a configuração do caixa atual."
		Return .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao permite valor negativo no campo quantidade quando nao ha concomitancia ou se PAF-ECF     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lVAssConc .OR. LjNfPafEcf(SM0->M0_CGC)
	If nField == 1 .And. ReadVar() == "M->LR_QUANT" .AND. M->LR_QUANT <= 0
		If !lAutoExA
			MsgStop(STR0038) // Valor nao permitido para esse campo.
		Else
			ConOut(STR0038) // Valor nao permitido para esse campo.
		EndIf
		LjGrvLog(SL1->L1_NUM, STR0038 + " M->LR_QUANT" ,M->LR_QUANT,)//Valor nao permitido para esse campo.
		Return .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao permite efetuar alteracoes nos campos se jah foi efetuada³
//³ a reserva                                                    ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ( "LR_" $ ReadVar() .And. &(ReadVar()) != GDFieldGet(Replace(ReadVar(),"M->","")) ) .And. ;
	( Len(aColsDet) >= n .AND. !Empty(aColsDet[n][nPosDtReserva]) .AND. !lFtvdVer12 .OR. ;
	Len(aColsDet) >= n .AND. !Empty(aColsDet[n][nPosDtReserva]) .AND. !lAutoExA .AND. lFtvdVer12 ) .AND.; 
	!lIntSynt .AND. !lIntegDef
	If !lAutoExA
		Aviso( STR0001, STR0002, {STR0003} ) //"Aviso"###"Já existe uma reserva para esse produto, não é possível ser alterado."###"Ok"
	Else
		ConOut(STR0002)
	EndIf
	LjGrvLog(SL1->L1_NUM, STR0002)//"Já existe uma reserva para esse produto, não é possível ser alterado."
	Return .F.
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Armazena a linha atual (aCols e aColsDet). Quando o caixa nao³
//³teve sucesso na tentativa de conceder descontos, os valores  ³
//³antigos serao restaurados, mesmo que ja tenham sofrido algum ³
//³desconto                                                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
AAdd(aDescBkp,aClone(aCols[n]))
If Len(aColsDet) >= N
	AAdd(aDescBkp,aClone(aColsDet[n]))
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifico se o Profile do usuario permite que execute descontos   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (nField == 3 .OR. nField == 4)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Caso queira alterar o desconto, volta o preco da venda para ³
	//³o original.                                                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    If !Empty(aCols[n][nPosProd])
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Altera desconto percentual.³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nField == 3 .AND. aCols[n][nPosDesc] <> 0
			aCols[n][nPosVlUnit]	:= aColsDet[n][nPosPrcTab]
			aCols[n][nPosVlItem]	:= A410Arred(aCols[n][nPosVlUnit] * aCols[n][nPosQuant],"LR_VLRITEM",nMoedaCor)
			aCols[n][nPosValDesc]	:= 0
			M->LR_VALDESC			:= 0
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Altera desconto valor.     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nField == 4 .AND. aCols[n][nPosValDesc] <> 0
			aCols[n][nPosVlUnit]	:= aColsDet[n][nPosPrcTab]
			aCols[n][nPosVlItem]	:= A410Arred(aCols[n][nPosVlUnit] * aCols[n][nPosQuant],"LR_VLRITEM",nMoedaCor)
			aCols[n][nPosDesc]		:= 0
			aCols[n][nPosValDesc]	:= 0
			M->LR_DESC				:= 0
		EndIf
	Endif

	If (nField == 3) .AND. !lCalcDesc
	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
    	//| Venda assistia concomitante, entao limpa o campo do Vlr.desconto qdo for digitado em Perc.Desconto  |
 		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lVAssConc  // Quando e venda concomitante
           aCols[n][nPosValDesc] := 0
	       Return .T.
	    Else
			If !Empty(aCols[n][nPosProd])
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Validacao do Desconto. ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	           	nDescP := &(ReadVar())
				nDescV := aCols[n][nPosQuant] * aColsDet[n][nPosPrcTab] * IIf( ValType(nDescP) == "N", nDescP, 0)  / 100
		    	aDesc := {"P", nDescP}
		    	nPosIt := aCols[n][nPosItem]
	    	Endif
		EndIf
	ElseIf (nField == 4) .AND. !lCalcDesc
	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
    	//| Venda assistia concomitante, entao limpa o campo do Perc.desconto qdo for digitado em Vlr.Desconto  |
 		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	    If lVAssConc
           aCols[n][nPosDesc] := 0
	       Return .T.
	    Else
			If !Empty(aCols[n][nPosProd])
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Release 11.5 - Chile - F1CHI                               ³
				//³Sempre arredondar o valor do desconto digitado pelo usuario³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If cPaisLoc == "CHI" .AND. M->LR_VALDESC > 0
					M->LR_VALDESC := A410Arred( M->LR_VALDESC,"LR_VALDESC",nMoedaCor)
				Endif

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Validacao do Desconto. ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lMvAjstDes
					nDescV := AjtDscIt( M->LR_VALDESC, aCols[n][nPosQuant] )
					M->LR_VALDESC := nDescV
				EndIf
				nDescP := &(ReadVar()) * 100 / (aCols[n][nPosQuant] * aColsDet[n][nPosPrcTab])
	            nDescV := &(ReadVar())
				aDesc := {"V",nDescV}
				nPosIt := aCols[n][nPosItem]
			Endif
		EndIf
	EndIf
	If !lRegrDesc .AND. !lCalcDesc .AND. !lIntegDef .AND. !LjProfile(	11		, Nil	, aDesc		, nDescP	,;
					 nDescV	, Nil	, M->LQ_NUM, Nil, nPosIt ) 
		nDescP		:= 0
		nDescV		:= 0
		aDesc		:= {"V", 0}
		nPosIt		:= 0
		aCols[n]	:= aClone(aDescBkp[1])
		If Len(aDescBkp) > 1
			aColsDet[n]	:= aClone(aDescBkp[2])
		EndIf
		LjGrvLog(SL1->L1_NUM, STR0121)
 		Return .F.
	EndIf
ElseIf nField == 2
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Valida se o produto existe no SB1 e SB0                                        ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea( "SB1" )
	DbSetOrder( 1 )
	If !DbSeek( xFilial("SB1") + aCols[n][nPosProd] )
		RestArea(aArea)
		If nBkPrcTab > 0
			aColsDet[n][nPosPrcTab] := nBkPrcTab
		EndIf
		LjGrvLog(SL1->L1_NUM, STR0122,aCols[n][nPosProd])//"Produto não cadastrado" 
		Return .F.
	EndIf

	If !LjxeValPre (@nPrecoTab	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
					nMoedaCor	, aCols[n][nPosQuant])

		If nBkPrcTab > 0
			aColsDet[n][nPosPrcTab] := nBkPrcTab
		EndIf
        LjGrvLog(SL1->L1_NUM, STR0123,aCols[n][nPosProd])//"Problemas na apuração do preço do Produto" 
		Return .F.
	EndIf

EndIf

//Sinaliza que item de Abastecimento, considera valor do aCols
If ((nPosLegCod > 0) .AND. !Empty(aCols[n][nPosLegCod]))
	lItemAbast := .T.
EndIf

If !Atail(aCols[n])	//verifica se o item nao esta deletado
   nVlItem	 := IIf(lItemAbast,0,aCols[n][nPosVlItem] )
   If nKit == 0 //Padrao
		If (!lCenVenda .Or. lAplRgDesT .OR. lFtvdVer12) .AND. !lScCsPreco
			If ReadVar() $ "M->LR_QUANT|M->LR_VRUNIT|M->LR_PRODUTO"
				Lj7T_DescP(2,0)
				Lj7T_DescV(2,0)
			EndIf
		EndIf
	   
	   nAuxTotal := LJ7T_Subtotal(2) - If( MaFisFound("IT",n),MaFisRet( n, "IT_TOTAL" ),nVlItem )
   Else
	   nAuxTotal := LJ7T_Subtotal(2) //estava subtraindo o valor do primeiro produto do sub-total
   Endif
EndIf

DbSelectArea( "SB1" )
SB1->( DbSetOrder(1) )	//B1_FILIAL + B1_COD
If SB1->( DbSeek(xFilial("SB1") + aCols[n][nPosProd]) )

	// Caso o preco vim da execAuto ou Synteses pega o preco passado no array
	If lRet .AND. ( lIntSynt .OR. (lAutoExA .AND. !Empty(aColsDet[n][nPosPrcTab]) ))
		nPrecoTab := aColsDet[n][nPosPrcTab]
	ElseIf !LjxeValPre (@nPrecoTab	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
					nMoedaCor	, If(nField==1,&(ReadVar()),aCols[n][nPosQuant]) )
		LjGrvLog(SL1->L1_NUM, STR0123 ,aCols[n][nPosProd])//"Problemas na apuração do preço do Produto"	    			
	    Return .F.
	EndIf

	If SB1->B1_VALEPRE == "1"
		If Iif( nField == 1, &(ReadVar()), aCols[N][nPosQuant] ) <> 1
			If nField == 1
				If !lAutoExA
					Aviso( STR0004,STR0052, {STR0003} ) //"Atenção"#"Vales presentes devem ser vendidos de 1 em 1 para que se possa controlar sua rastreabilidade."#"OK"
				Else
					ConOut(STR0052)
				EndIf 
				LjGrvLog(SL1->L1_NUM, STR0052)//"Vales presentes devem ser vendidos de 1 em 1 para que se possa controlar sua rastreabilidade."
				Return .F.
			Else
				aCols[N][nPosQuant] := 1
			EndIf
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se o produto utiliza controle por lote, valida a quantidade³
	//³solicitada                                                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If  ((cRastro == "S") .AND. ((Len(aColsDet) >= N) .AND. (!Empty(aColsDet[n][nPosLoteCtl]))))

	   If Empty(aColsDet[N][nPosLoteCtl])
	       aColsDet[N][nPosLoteCtl] := Space(TamSX3("LR_LOTE")[1])
	   EndIf
	   
	   If Empty(aColsDet[N][nPosSubLote])
	       aColsDet[N][nPosSubLote] := Space(TamSX3("LR_NLOTE")[1])
	   EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se o lote selecionado corresponde ao produto corrente³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		SB8->(DbSetOrder(3)) //B8_FILIAL+B8_PRODUTO+B8_LOCAL+B8_LOTECTL+B8_NUMLOTE+DTOS(B8_DTVALID)
		If SB8->(DbSeek(xFilial("SB8") + aCols[N][nPosProd] + aColsDet[N][nPosDtLocal] + aColsDet[N][nPosLoteCtl] + aColsDet[N][nPosSubLote]))
			nQuant	:= If( nField == 1, &(ReadVar()), aCols[N][nPosQuant] )
			If !Lj7Lote(aColsDet[N][nPosDtLocal], aColsDet[N][nPosLoteCtl], aColsDet[N][nPosSubLote], nQuant )
				RestArea(aArea) 
				LjGrvLog(SL1->L1_NUM, STR0124 ,aCols[N][nPosProd])//"Lote selecionado não corresponde ao produto"
				Return .F.
			EndIf
		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Se o produto do lote indicado nao corresponde, os dados do³
			//³lote sao limpos                                           ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			aColsDet[n][nPosLoteCtl] := Space(nTamB8_NUMLOTE)
			aColsDet[N][nPosSubLote] := Space(nTamB8_LOTECTL)
		EndIf
	EndIf

   	If nField == 3 .OR. nField == 4
   		If nMvLjTpDes == 0
	   		If !(lECommerce .AND. lMvLjIPEn)
	   			nVlUnit := (aCols[n][nPosVlItem] + aCols[n][nPosValDesc]) / aCols[n][nPosQuant]
	   		ElseIf lMvLjIPEn
	   			nVlUnit := aColsDet[n][nPosPrcTab]
	   		EndIf
	   	ElseIf nMvLjTpDes == 2
	   	    nValorItem := aColsDet[n][nPosPrcTab]
   	    	nVlUnit := nValorItem
	   	Else
			LjxeValPre (@nValorItem	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
						nMoedaCor	, aCols[n][nPosQuant])
	   		nVlUnit	:= oDesconto:DescontoValor( nValorItem, aCols[n][nPosQuant], aCols[n][nPosValDesc] )
	   	Endif
	ElseIf nField == 2
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Só permite alterar o preco unitario se o usuario escolher uma tabela de preco  ³
		//³ zerada. Este é um conceito do SIGALOJA.                                        ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nField == 2 .AND. nPrecoTab > 0 .AND. !lAlterPre .And. !IsInCallStack("LJNFCELOT") //Quando Finalização de NFCE em Lote, a validação ja foi efetuada, quando salvo orçamento anteriormente.
			Help( " ", 1, "LJ010NOVAL" )

			If nBkPrcTab > 0
				aColsDet[n][nPosPrcTab] := nBkPrcTab
			EndIf

			Return .F.
		EndIf

		If !lValePre
			nVlUnit := &(ReadVar())
		Else
			nVlUnit := aCols[n][nPosVlUnit]
		EndIf
	Else
		If lFtvdVer12
			If ReadVar() == 'M->LR_TES' .And. nField == 0
				nVlUnit := aCols[n][nPosVlUnit]
			Else
				LjxeValPre (@nVlUnit	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
					nMoedaCor	, If(nField==1,&(ReadVar()),aCols[n][nPosQuant]) )
			EndIf
		ElseIf !lFtvdVer12
			LjxeValPre (@nVlUnit	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
						nMoedaCor	, If(nField==1,&(ReadVar()),aCols[n][nPosQuant]) )
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se o preço da tabela for zero e a funcao for chamada da digita-	³
		//³ cao do campo quantidade (nField = 1) entao traz o valor digita-	³
		//³ do previamente, caso contrario, traz o valor da tabela         	³
		//³          														³
		//³ OU         														³
		//³          														³
		//³Release 11.5 - Cartao Fidelidade									³
		//³Se o produto for do tipo recarga de cartão fidelidade            ³
		//³(ver parametro MV_LJPFID), o preco informado no cadastro   		³
		//³do produto sera desconsiderado.O valor mantido sera o       		³
		//³informado na tela de inclusao de saldo do cartao fidelidade.		³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

		If (nVlUnit == 0 .AND. nField = 1) .OR. (lLjcFid .AND. LaFunhProd(aCols[n][nPosProd]))
			nVlUnit := (aCols[n][nPosVlItem] + aCols[n][nPosValDesc]) / aCols[n][nPosQuant]
		EndIf

	    If lTrcMoeda .AND. !lCenVenda .AND. !lIntegDef //Integracao nao atualiza valor unitario do produto
	       nMoedaPrv := Max(&("SB0->B0_MOEDA" + Lj7DefTab()),1)
		   nVlUnit   := Round(xMoeda(&("SB0->B0_PRV" + Lj7DefTab()),nMoedaPrv,nMoedaCor,dDataBase,nDecimais+1,,nTxMoeda),nDecimais)
	    EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se for item de Abastecimento(TPL POSTO) ou finalizacao de Lay-Away, considerar o valor ja preenchido no aCols ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lItemAbast .OR. ((cPaisLoc$"EUA|POR|MEX|COL") .AND. lLayAway) .OR. ( (lIsRecCel .Or. lIsRecCP .Or. lAutoExA) .And. aCols[n][nPosVlUnit] > 0;
																											.AND. !IsInCallStack("Lj7CpGrvOr") )
	   nVlUnit  := aCols[n][nPosVlUnit]
	Endif

	//Checar se o valor digitado no desconto por valor, eh maior que o B0_PRV mais a tabela selecionada
	If ( nField == 4 ) .AND. ( M->LR_VALDESC >= (A410Arred(nVlUnit * aCols[n][nPosQuant],"LR_VLRITEM",nMoedaCor)) ) .AND. !lECCia
		If !lAutoExA
			Aviso(STR0004,STR0005,{STR0003} ) //"Atenção"###"O valor do desconto é maior ou igual ao valor do item, verifique !"###"Ok"
		Else
			ConOut(STR0005)
			Help( " ", 1, "Help",, STR0005, 1, 0 )
		EndIf
		RestArea(aArea)
		Return .F.
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Valida se o valor unitário foi alterado, zera os descontos³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (!lCenVenda .Or. lAplRgDesT .OR. lFtvdVer12) .AND. !lScCsPreco .AND. (nKit == 0 .AND. AllTrim(aCols[n][nPosKit]) == "")
		If ReadVar()$"M->LR_QUANT|M->LR_VRUNIT|M->LR_PRODUTO"
			Lj7T_DescP(2,0)
			Lj7T_DescV(2,0)
			If "M->LR_PRODUTO"$ReadVar()
				aCols[n][nPosDesc]		:= 0
				aCols[n][nPosValDesc]	:= 0
			Endif
		Endif
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atribui valor unitario										 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nValUnitAnt          := aCols[n][nPosVlUnit]
	aCols[n][nPosVlUnit] := nVlUnit

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Calcula valor do item										 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nQuant	:= If( nField=1, &(ReadVar()), aCols[n][nPosQuant] )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ponto de entrada para indicar se o ECF faz o arredondamento (.T.) ou ³
	//³ truncamento (.F.) dos valores.                                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If ExistBlock("FRTECF13")
		LjGrvLog(M->LQ_NUM,"Antes da execução do PE FRTECF13",{aCols[n][nPosProd],aCols[n][nPosVlUnit], nQuant})
	    lStatusImp13 := ExecBlock("FRTECF13",.F.,.F.,{aCols[n][nPosProd],aCols[n][nPosVlUnit], nQuant})
	    LjGrvLog(M->LQ_NUM,"Depois da execução do PE FRTECF13",lStatusImp13)
		
		If lStatusImp13  // Se o ECF Nao Tem Arredondamento
			aCols[n][nPosVlItem]	:= Round( nQuant * aCols[n][nPosVlUnit], TamSx3("D2_TOTAL")[2])
		Else
			aCols[n][nPosVlItem]	:= NoRound( nQuant * aCols[n][nPosVlUnit], TamSx3("D2_TOTAL")[2])
		EndIf
	Else
		aCols[n][nPosVlItem]	:= a410Arred( nQuant * aCols[n][nPosVlUnit], "D2_TOTAL")
	Endif

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se permite vender com estoque negativo. Aqui soh    ³
	//³ faz um alerta e não trava a operacao, pois poderah se tratar ³
	//³ de um orcamento ou de uma reserva para outra loja.           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nField == 1 .AND. !lEstNeg
		If Len(aColsDet) >= n
			cLocal := aColsDet[n][nPosDtLocal]
			If  ValType(cLocal) == "U" .OR. Empty(cLocal)
 				cLocal := RetFldProd(SB1->B1_COD,"B1_LOCPAD")
			EndIf
		Else
			cLocal := RetFldProd(SB1->B1_COD,"B1_LOCPAD")
		Endif		
		lValEst := Lj7VerEst( aCols[n][nPosProd], cLocal, nQuant, .T. )
		
		//Integracao nao continua se estoque negativo
		If lIntegDef
			If !lValEst
				Return .F.
			EndIf
		EndIf
	Endif



	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se ha desconto (valor e ou percentual)              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nField == 1 
		
		If nPosKit > 0
			lKit = IIf(AllTrim(aCols[n][nPosKit]) <> "", .T., .F.)
		EndIf 
		
		If lKit
			If aCols[n][nPosDesc] > 0//Se o percentual de desconto for maior que 0
				nVlrDesc := Round( aCols[n,nPosDesc] * aCols[n][nPosVlItem] / 100, nDecimais )
				// Ajusta o Valor de desconto
				If nVlrDesc <> 0
					aCols[n][nPosValDesc] 	:= nVlrDesc
					aCols[n][nPosVlItem]	-= nVlrDesc
					aCols[n][nPosVlUnit]    -= nVlrDesc/aCols[n][nPosQuant]
				Endif
			EndIf 
		Else 
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Verifica a regra de descontos de acordo com a quantidade³
			//³vendida - Cenario de vendas                             ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If (((SB1->(ColumnPos("B1_DESCONT")) > 0)  	.AND. (SB1->B1_DESCONT > 0))  .OR. lLJ8099)
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Calcula o desconto a partir do PE ou B1 %S³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lLJ8099
					LjGrvLog(M->LQ_NUM,"Antes da execução do PE Lj8099")
					aCols[n][nPosDesc]	:= Execblock( "LJ8099", .F., .F. )
					LjGrvLog(M->LQ_NUM,"Antes da execução do PE Lj8099",aCols[n][nPosDesc])
				Else
					aCols[n][nPosDesc]	:= SB1->B1_DESCONT
				EndIf
			ElseIf lCenVenda

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Calcula o desconto a partir da regra de descontos - ITENS³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nRegDesc := LjRgrDesc(aCols[n][nPosProd],M->LQ_CLIENTE,M->LQ_LOJA,cTabPad,M->LR_QUANT ,1)

				aCols[n][nPosDesc] := nRegDesc
			EndIf

			nAuxPrItem := aCols[n][nPosDesc]

			If aCols[n][nPosValDesc] > 0 .OR. lCenVenda

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Se o percentual de desconto for maior que 0, refaz o cálculo do valor do desconto. ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If nMvLjTpDes == 0
					nVlrDesc := Round( aCols[n,nPosDesc] * aCols[n][nPosVlItem] / 100, nDecimais )
				ElseIf nMvLjTpDes == 2
				If  aCols[n][nPosValDesc] > 0
						nVlUnit := aColsDet[n][nPosPrcTab]
						nVlrPDesc := oDesconto:CalcPerDes(@nVlUnit, @nVlrDesc ,nQuant )
					EndIf
					If aCols[n][nPosDesc] > 0
						nVlUnit := aColsDet[n][nPosPrcTab]
						nVlrDesc := oDesconto:CalcValDes( @nVlUnit , aCols[n][nPosDesc], nQuant )
					EndIf
				Else
					nVlrDesc := oDesconto:ValidaValor( aCols[n][nPosDesc], nVlUnit, nQuant )
				Endif
				aCols[n][nPosValDesc] 	:= nVlrDesc

				aCols[n][nPosVlItem]	-= nVlrDesc
				If nMvLjTpDes <> 2
					aCols[n][nPosVlUnit] := ( aCols[n][nPosVlItem] / M->LR_QUANT )
				Else
					aCols[n][nPosVlUnit] := nVlUnit
				EndIf
				aDesconto				:= { 0, 0, 0 }

			EndIf

		EndIf 

	ElseIf nField == 2
		If aCols[n][nPosValDesc] > 0 .AND. nValUnitAnt <> M->LR_QUANT

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Se alterar o valor do item unitario, zera os descontos                             ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		    nVlrDesc 				:= 0
		    aCols[n][nPosValDesc] 	:= 0
		    aCols[n][nPosDesc] 		:= 0
			aDesconto				:= { 0, 0, 0 }

		EndIf

	ElseIf nField == 3
	    If nMvLjTpDes == 0
	        nVlrPDesc := aCols[n][nPosDesc]		//guardando % de desconto anterior
	    	nVlrDesc  := Round( IIf(lCalcDesc, aCols[n][nPosDesc], M->LR_DESC) * aCols[n][nPosVlItem] / 100, nDecimais )
	    ElseIf nMvLjTpDes == 2
	    	If !Empty ( M->LR_VALDESC ) .AND.  M->LR_VALDESC > 0
	    		nVlrPDesc := oDesconto:CalcPerDes(@nVlUnit, nVlrDesc , nQuant )
	    	EndIf
	    	If !Empty ( M->LR_DESC ) .AND. M->LR_DESC > 0
	    		nVlrDesc := oDesconto:CalcValDes( @nVlUnit , M->LR_DESC , nQuant )
	    	EndIf
	    Else
		    If IIf(lCalcDesc, Empty( aCols[n][nPosDesc] ), Empty( M->LR_DESC ))
		    	nVlrPDesc := oDesconto:ValidaPercent( nVlrDesc, nVlUnit, nQuant )
		    EndIf

		    If IIf(lCalcDesc, Empty( aCols[n][nPosValDesc] ), Empty( M->LR_VALDESC )) .OR. aCols[n][nPosValDesc] == 0
		    	nVlrDesc := oDesconto:ValidaValor( IIf(lCalcDesc, aCols[n][nPosDesc], M->LR_DESC), nVlUnit, nQuant )
		    Endif
		EndIf

		// Ajusta o Valor de desconto
	    aCols[n][nPosDesc]		:= nVlrPDesc
	    aCols[n][nPosValDesc] 	:= nVlrDesc
	ElseIf nField == 4
		If !nMvLjTpDes == 2
			nVlrDesc 				:= IIf(lCalcDesc, aCols[n][nPosValDesc], M->LR_VALDESC)
			nVlrPDesc 				:= Round( nVlrDesc * 100 / aCols[n][nPosVlItem], aTamL2DESC[2] )
			// Ajusta o Percentual de desconto
			aCols[n][nPosDesc]		:= nVlrPDesc
		Else
		    If M->LR_VALDESC > 0
		    	If lMvAjstDes
					M->LR_VALDESC := AjtDscIt( M->LR_VALDESC, aCols[n][nPosQuant] )
				EndIf
		    	nVlrDesc :=	M->LR_VALDESC
		    EndIf
		    If nVlrDesc > 0
				nVlrPDesc := oDesconto:CalcPerDes(@nVlUnit, nVlrDesc , nQuant )
				aCols[n][nPosDesc] := nVlrPDesc
			EndIf
		EndIf
	Endif

	// Ajusta os valores de preco unitario e total do item
	If nField == 3 .OR. nField == 4
    	If nMvLjTpDes == 0  .OR. nMvLjTpDes == 1
    		aCols[n][nPosVlItem]	-= nVlrDesc
    		aCols[n][nPosVlUnit]	:= aCols[n][nPosVlItem] / aCols[n][nPosQuant]
    	Else
    	    aCols[n][nPosVlItem] 	-= nVlrDesc
       		aCols[n][nPosVlUnit]	:= nVlUnit
    	EndIf
	Endif

	If nField == 0 .AND. nKit == 1
		If aCols[n][nPosDesc] > 0//Se o percentual de desconto for maior que 0

		    nVlrDesc := Round( aCols[n,nPosDesc] * aCols[n][nPosVlItem] / 100, nDecimais )

			// Ajusta o Valor de desconto
		    If nVlrDesc <> 0
			    aCols[n][nPosValDesc] 	:= nVlrDesc
			    aCols[n][nPosVlItem]	-= nVlrDesc
			    aCols[n][nPosVlUnit]    -= nVlrDesc/aCols[n][nPosQuant]
		    Endif
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Faz o ajuste do array de Detalhe dos produtos e chama as     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

	If lVAssConc .AND. nField==0   // Quando e venda concomitante

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifico os valores dos descontos digitados ou percentual ou valor   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nVlPd_cpo3 <> 0
			nVlrDesc 			:= Round( nVlPd_cpo3 * aCols[n][nPosVlItem] / 100, nDecimais )
			nVlrPDesc			:= nVlPd_cpo3
			aCols[n][nPosDesc]	:= nVlPd_cpo3
		ElseIf nVDes_cpo4 <> 0
			nVlrDesc			:= nVDes_cpo4
			nVlrPDesc 			:= Round( nVlrDesc * 100 / aCols[n][nPosVlItem], aTamL2DESC[2] )
			aCols[n][nPosDesc]	:= nVlrPDesc
		Else
			nVlrDesc := 0
		Endif

  		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se o considera % OU valor de desconto, ou, ³
		//³% E valor de desconto                               ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cFormDesc == "1"
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Chamado a partir do GET da porcentagem.³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nVlPd_cpo3<>0
				aDesc := { "P", nVlrPDesc }
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Chamado a partir do GET do valor.³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			ElseIf nVDes_cpo4<>0
				aDesc := { "V", nVlrDesc }
			EndIf

		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Se o caixa nao puder conceder o desconto informado no acols, desfaz³
		//³todas as alteracoes realizadas no item ate este ponto da funcao.   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If !lRegrDesc .AND. !LJProfile(11, Nil, aDesc, nVlrPDesc, nVlrDesc)

			If Len(aDescBkp) > 1
				aColsDet[n]			:= aClone(aDescBkp[2])
			EndIf
            LjGrvLog(SL1->L1_NUM, STR0125)//"Problemas no desconto do produto"
			aCols[n]   		   		:= aClone(aDescBkp[1])
			aCols[n][nPosProd] 		:= ""
			aCols[n][nPosDescri]	:= ""
			M->LR_PRODUTO 			:= ""

			RestArea(aArea)
			Return .F.

		EndIf

		If nVlrDesc <> 0
		//somente atualizo o Valor Unitario, caso valor de desconto <> 0
			aCols[n][nPosVlItem]	-= nVlrDesc
			aCols[n][nPosVlUnit]	:= aCols[n][nPosVlItem] / aCols[n][nPosQuant]
			aCols[n][nPosValDesc]	:= nVlrDesc
		EndIf

	Endif

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Faz o ajuste do array de Detalhe dos produtos e chama as     ³
	//³ funcoes fiscais para calcular os impostos                    ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lFtvdVer12
		LjGrvLog(M->LQ_NUM," Antes da Função LJ7Detalhe")
		LJ7Detalhe(Nil, lAlterProd, Nil, Nil, lIsRecCP, aCols[n][nPosVlUnit], lReproVlIt)
		LjGrvLog(M->LQ_NUM," Depois da Função LJ7Detalhe")
	ElseIf lFtvdVer12
		LjGrvLog(M->LQ_NUM," Depois da Função LJ7Detalhe - FTVD12")
		LJ7Detalhe(, , ,ReadVar())
		LjGrvLog(M->LQ_NUM," Depois da Função LJ7Detalhe - FTVD12")
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Faz ajuste do acols, porque a rotina está zerando mesmo ³
	//³quando é chamada da validação do Item com desconto.     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (nValDes > 0 .Or. ReadVar()=="M->LR_DESC") .AND. (nVlrDesc > 0)
		aCols[n][nPosDesc] 	:= &(ReadVar())
	EndIf
	
	If lFtvdVer12
		//Realiza o calculo do Suframa, quando o cliente for Apto a recebe-lo
		If cPaisLoc == "BRA" .AND. MaFisRet(,"NF_SUFRAMA")
			nSuframa := LjVDSuframa()
		EndIf

		//Atualiza o valor de desconto do suframa
		If Len(aTotais) > 6
			LjVDT_SUFR( 2, nSuframa	)
		EndIf
		
		nAuxTotal := MaFisRet(, "NF_TOTAL" ) + IIF(LjNewCalSol() , Lj7T_DescV(2) , 0)
	EndIf

	//Atualiza Subtotal e Total jah com os impostos calculados 
	If !lFtvdVer12 .And. cPaisLoc == "BRA" .AND. !aCols[n][Len(aHeader) + 1] 
		nAuxTotal := nAuxTotal + If( MaFisFound("IT",n),MaFisRet( n, "IT_TOTAL" ),aCols[n][nPosVlItem] )
	EndIf

	If cPaisLoc <> "BRA" .And. nRotina == 4
		aCols[n][nPosValDesc] 	:= nVlrDesc
		If lRecalcIt
			//Zera o desconto proporcional dos itens devido ter zerado o desconto no total
			For nX := 1 To Len(aCols)
				If !aCols[nX][Len(aCols[nX])]
					aColsDet[nX][nPosDtDProp] := 0
				EndIf
			Next nX
		EndIf
	EndIf

	If !Atail(aCols[n]) .AND. !lCalcDesc 
		// Significa que o usuario incluiu um novo produto ou alterou algum item após determinar
		// um desconto no total. Nesse caso é necessário recalcular os impostos para todos os itens.
		If cPaisLoc <> "BRA"
			Lj7T_Total( 2, 0 )
			Lj7T_Subtotal( 2, 0 )
			Lj7T_Quant( 2, 0 )
			aTotImpsV := {} //Limpa array com o total dos Impostos Variaveis que serao recalculados logo abaixo

			For nX := 1 To Len(aCols)
				If !aCols[nX][Len(aCols[nX])]
					Lj7RecalImp(nX	, 1  , NIL ,	NIL,;
								NIL	, NIL, NIL, .T. )
				EndIf
			Next nX
			lRecalcIt := .F.
		Else
			Lj7T_Subtotal( 2, nAuxTotal )

    		nAuxQuant := Lj7CalcQtd(aCols,n,nQuant)

			If !lFtvdVer12
    			IIF(!MaFisRet(,"NF_SUFRAMA"),Lj7T_Quant( 2, nAuxQuant ),Nil)
            EndIf
            
            LjGrvLog(M->LQ_NUM," Existe desconto no cabeçalho ?",lDescCab)
            LjGrvLog(M->LQ_NUM," Caixa pode aplicar desconto quando MV_LJCNVDA com .T. ?",LjOpcDesc())
            
			If !lDescCab .And. LjOpcDesc()
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Caso possua desconto no total e foi informado desconto no item,                           ³
				//³O desconto no total eh zerado pois não pode ser recalculado, o que implicaria em verificar³
				//³a pemissao do usuario. Neste caso deve ser informado novamente o desconto no total.       ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If Lj7T_DescV(2) > 0 .AND. nVlrDesc > 0
					Lj7T_DescV(2, 0)
					Lj7T_DescP(2, 0)
					
					LjGrvLog(M->LQ_NUM," Desconto no Total + Desconto no item - Será Zerado ")
					
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//|Se os descontos sao aplicados nessa ordem: 1-desconto no ITEM, 2-desconto no TOTAL e por ultimo,	|
				//| ZERA-SE o desconto no ITEM, o sistema deve reaplicar automaticamente o desconto no TOTAL.		|
				//|Mas se for aplicado um novo desconto no IT, o desconto no TOTAL deve ser reaplicado manualmente	|
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				ElseIf Lj7T_DescP(2) > 0 .AND. nVlrDesc <= 0
					
					LjGrvLog(M->LQ_NUM," Desconto Ordenado ")
					LjGrvLog(M->LQ_NUM," Valor do Subtotal ",Lj7T_SubTotal(2))
					LjGrvLog(M->LQ_NUM," Valor do solidário da nota ",MaFisRet(,"NF_VALSOL"))
					
					nPerDesc := Lj7T_DescP(2)
					nVlrDesc := nVlrDescBkp := A410Arred( (Lj7T_SubTotal(2) - MaFisRet(,"NF_VALSOL")) * nPerDesc / 100, "L1_DESCONT")
					
					Lj7T_DescV(2, nVlrDesc)
					Lj7T_DescP(2, nPerDesc)
					
					LjGrvLog(M->LQ_NUM," Valor do Desconto ",nVlrDesc)
					LjGrvLog(M->LQ_NUM," Valor do Percentual de Desconto ",nPerDesc)
				EndIf
			EndIf
			Lj7T_Total( 2, Lj7T_Subtotal(2) - Lj7T_DescV(2) )
			
			LjGrvLog(M->LQ_NUM," Valor Total ",Lj7T_Total( 2 ))
			LjGrvLog(M->LQ_NUM," Valor SubTotal ",Lj7T_Subtotal( 2 ))
			LjGrvLog(M->LQ_NUM," Valor Desconto ",Lj7T_DescV( 2 ))

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Ao alterar o produto, verifica se novo total eh menor ou igual a 0 ³
			//³(devido aos descontos) se for, zera os descontos e refaz o calculo ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aTotais[4][2] <= 0
				Lj7T_DescV(2, 0)
				Lj7T_DescP(2, 0)
				Lj7T_Total( 2, Lj7T_Subtotal(2) - Lj7T_DescV(2) )
			Endif

			//Armazena Condicao de Pagamento Atual
			If M->LQ_CONDPG <> Nil
				cCondBkp := M->LQ_CONDPG
			EndIf

   			If !lPBMDesc .AND. ExistTemplate("DROVLGet")
   				aPgtoEx := {"CO"}
   			EndIf
			
			If Len(aVidaLink) > 2  .And. aVidaLink[3] <> 1 //para nao remover o desconto do adcionado pelo PBM Funcional Card
				If Len(aColsDet) < n .OR. nPosCodBar = 0
					nPosPBM := aScan(aVidaLink[1][2],{|x| Len(x) > 9 .And. x[10] == n .And. x[2] == AllTrim(aCols[n][nPosProd]) })
				Else
					nPosPBM := aScan(aVidaLink[1][2],{|x| Len(x) > 9 .And. x[10] == n .And. x[2] == AllTrim(aColsDet[n][nPosCodBar]) })
				EndIf

				If nPosPBM > 0
					Lj7ZeraPgtos( NIL, NIL, .F. )
				EndIf	
			Else
				Lj7ZeraPgtos( NIL, NIL, .F., aPgtoEx )
			EndIf
   			
   			aDesconto := { 0, 0, 0 }
   
   			//Restaura Condição de Pagamento, necessário para Regra de Desconto pois Lj7ZeraPgtos limpa M->LQCONDPG
   			If cCondBkp <> Nil
   				M->LQ_CONDPG := cCondBkp
   			EndIf
		EndIf
	Endif

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Calcula o desconto da venda a partir das regras de desconto³
	//³do cenario de vendas                                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nField == 1 .AND. lCenVenda

		aColsTmp	:= aClone(aCols)
		aColsTmp[n][nPosQuant] := M->LR_QUANT

  		nValDscIt	:= 0
		aEval( aCols, { |x| nValDscIt += If(x[nPosDelet],0,x[nPosValDesc])} )
		nTotal		:= Lj7T_Subtotal(2) + Lj7T_DescV(2) + nValDscIt

		LjDescCab(	aColsTmp[n][nPosProd]	, M->LQ_CLIENTE	, M->LQ_LOJA	, @aColsTmp	,;
					@aHeader				, nTotal		)
	EndIf
EndIf

If cPaisLoc == "ARG"
	M->LR_VALDESC := aCols[n][nPosValDesc]
EndIf

Eval(bRefresh)

If nPosaCols <> n
	n := nPosaCols
EndIf

RestArea(aArea) // Restaura area anterior

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Caso parametro for .T. faz tratamento para classificação de desconto³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
LjGrvLog(M->LQ_NUM," Regra de desconto está ativa ?", lRegrDesc)

If !lRegrDesc .AND. Lj7Mv_Desc() .AND. !lAutoExA

    If oMotivoDes == Nil
		oMotivoDes := LJCClaDes():New()
	EndIf

	If 	(!aCols[n][nPosValDesc] == 0)  .AND.  (nBkDesc  <> aCols[n][nPosValDesc])	 .AND.;
		(nField == 3 .OR. nField == 4)

		If !oMotivoDes:ChamaTela(n)
			If Len(aDescBkp) > 1
				aColsDet[n]			:= aClone(aDescBkp[2])
			EndIf
			aCols[n]   		   		:= aClone(aDescBkp[1]) 
			LjGrvLog(SL1->L1_NUM, STR0125)//"Problemas no desconto do produto"
			Return .F.
		EndIF
	ElseIf aCols[n][nPosValDesc] == 0  .AND. (nField == 3 .OR. nField == 4)
		oMotivoDes:RmValida(n)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Grava Qtde dias da validade da garantia do produto   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lGE .AND. nPosDtVldProd > 0 .AND. Len(aColsDet) >= n

	If lCenVenda .AND. ExistBlock("LJ7080")
		LjGrvLog(M->LQ_NUM,"Antes da execução do PE LJ7080 - Produto:",aCols[n][nPosProd])
		nDiasGar := ExecBlock("LJ7080",.F.,.F.,{aCols[n][nPosProd]})
		LjGrvLog(M->LQ_NUM,"Depois da execução do PE LJ7080",nDiasGar)
	Else
		nDiasGar := SB0->B0_DIASGAR
	EndIf

	aColsDet[n][nPosDtVldProd] := nDiasGar
EndIf

LjGrvLog(M->LQ_NUM,"Fim da Função ")

Return .T.

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ Lj7VlGar  ³ Autor ³ Vendas Clientes      ³ Data ³ 05/01/11 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida a quantidade de produto com garantia estendida	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7VlGar()							                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701A													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7VlGar()

Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]			// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]			// Posicao do Valor unitario do item
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]			// Posicao do Valor do item
Local nPosValGar	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_GARANT"})][2]    		// Posicao do valor de desconto
Local nRet          := 0
Local lAutoExA		:= IsBlind()																		// Verifica se a rotina sera executada via execauto ou nao

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³só permite um produto de venda quando o mesmo ³
//³contém garantia estendida                     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nPosValGar > 0
	If !Empty(aCols[n][nPosValGar])
		If !lAutoExA
			MsgAlert(STR0070)          							// Só é permitido a venda de um produto por garantia estendida!
		Else
			Conout(STR0070)          							// Só é permitido a venda de um produto por garantia estendida!
		Endif
		aCols [n][nPosQuant] := 1
		aCols [n][nPosVlItem] := aCols [n][nPosVlUnit]
		lj7VlItem(5)
		nRet := aCols [n][nPosQuant]
	EndIf
EndIf
Return nRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³ Lj7T_VlTp ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida se o tipo do total que sera manipulado e valido	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_VlTp(nExp1, cExp2, uExp3)		                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Tipo que deve ser validado						  ³±±
±±³          ³ cExp2 - Nome do titulo (alterado SOMENTE pela equipe de	  ³±±
±±³          ³ desenvolvimento)											  ³±±
±±³          ³ uExp3 - Qual valor deve conter							  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7T_VlTp( nTipo, cNome, uValor )

Local lRet 		:= .T.							// Retorno da funcao
Local lAutoExA	:= IsBlind()					// Verifica se a rotina sera executada via execauto ou nao

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ O valor 4 representa o total de colunas do array aTotais	 ³
//³ Esta quantidade SOMENTE deve ser alterada pela equipe de 	 ³
//³ desenvolvimento.											 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nTipo <= 0 .OR. nTipo > 6
	If !lAutoExA
		Aviso(	STR0006,; //"Inconsistencia"
				STR0007 + cNome + STR0008 + CRLF +; //"Esta sendo enviado para a funcao "###" um TIPO que nao existe."
				STR0009	+ CRLF +; //"Isto podera ocasionar um erro no sistema."
				STR0010, {STR0003}) //"Verifique o 1o parametro dessa funcao"###"OK"
	Else
		ConOut(STR0007 + cNome + STR0008 + CRLF + STR0009 + CRLF + STR0010)
	EndIf
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se o parametro para atualizacao nao e NIL entao precisa ser	 ³
//³ avaliado se o tipo X parametro sao compativeis				 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If uValor <> Nil
	Do Case
		Case (nTipo == 1 .OR. nTipo = 4) .AND. ValType( uValor ) <> "C"
			lRet := .F.

		Case nTipo == 2 .AND. ValType( uValor ) <> "N"
			lRet := .F.

		Case nTipo == 3 .AND. ValType( uValor ) <> "O"
			lRet := .F.
	EndCase

EndIf

If !lRet
	If !lAutoExA
		Aviso(	STR0006,; //"Inconsistencia"
				STR0007 + cNome + STR0011 + CRLF +; //"Esta sendo enviado para a funcao "###" um TIPO incompativel"
				STR0012 + CRLF +; //"com o valor a ser recebido."
				STR0009 + CRLF +; //"Isto podera ocasionar um erro no sistema."
				STR0013, {STR0003}) //"Verifique o - 2o parametro dessa funcao"###"OK"
	Else
		ConOut(STR0007 + cNome + STR0011 + CRLF + STR0012 + CRLF + STR0009 + CRLF + STR0013)
	EndIf
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7T_Subtot³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o sub-total da venda				  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_Subtot(nExp1, uExp2)				                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do sub-total				  		  ³±±
±±³          ³ Lj7T_Subtot(1, "Valor bruto")							  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do sub-total						  ³±±
±±³          ³ Lj7T_Subtot(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_Subtotal( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7T_Subtotal", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 1, nTipo, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7T_DescP ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o desconto em percentual da venda	  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_DescP(nExp1, uExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do desconto em percentual			  ³±±
±±³          ³ Lj7T_DescP(1, "Desconto em percentual")					  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do desconto em percentual			  ³±±
±±³          ³ Lj7T_DescP(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_DescP( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7T_DescP", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 2, nTipo, uParam )

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³Lj7T_DescV ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o desconto em valor da venda	  	 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_DescV(nExp1, uExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do desconto em valor				  ³±±
±±³          ³ Lj7T_DescP(1, "Desconto em valor")						  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do desconto em valor				  ³±±
±±³          ³ Lj7T_DescV(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7T_DescV( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7T_DescV", uParam)
	Return .F.
EndIf

//Restaura o valor de ICMS Solidario, caso zera o desconto
If nTipo == 2 .And. ValType( uParam ) == "N" 
	If uParam == 0
		LjRestSol()
	Endif

	//Atribui o valor do desconto total na MatxFis para resgatar o valor correto de Impostos calculados
	LjDescFis( Lj7T_DescV(2), uParam )
EndIf

Return Lj7T_Array( 3, nTipo, uParam )

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Funcao    ³Lj7T_Total ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o valor total da venda	 		 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_Total(nExp1, uExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do valor total						  ³±±
±±³          ³ Lj7T_Total(1, "Valor total da venda")					  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do valor total						  ³±±
±±³          ³ Lj7T_Total(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7T_Total( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7Total", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 4, nTipo, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7T_TotPar³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o total das parcelas da venda	  	 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_TotPar(nExp1, uExp2)				                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do total da parcela 				  ³±±
±±³          ³ Lj7T_TotPar(1, "Total Parc.")						      ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do total das parcelas				  ³±±
±±³          ³ Lj7T_TotPar(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_TotPar( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7T_TotPar", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 5, nTipo, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7T_Troco ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o troco da venda	  	 	              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_TotPar(nExp1, uExp2)				                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do troco 							  ³±±
±±³          ³ Lj7T_Troco(1, "Troco") 								      ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o troco 									  ³±±
±±³          ³ Lj7T_Troco(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_Troco( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7T_Troco", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 6, nTipo, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7T_Array ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o array aTotais					  	  ³±±
±±³          ³ 														  	  ³±±
±±³          ³ Esta e a unica funcao que deve ALTERAR diretamente o array ³±±
±±³          ³ aTotais.												  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_Array(nExp1, nExp2, uExp3)		                  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Linha a ser manipulada					 		  ³±±
±±³          ³ nExp2 - Coluna ser manipulada					 		  ³±±
±±³          ³ uExp3 - Valor a ser recebido								  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Sub-total										  	  ³±±
±±³          ³ 2 - Desconto %										  	  ³±±
±±³          ³ 3 - Desconto $										  	  ³±±
±±³          ³ 4 - Total da venda									  	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp2, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do sub-total				  		  ³±±
±±³          ³ Lj7T_Array(1, 1, "Valor bruto")							  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do sub-total:						  ³±±
±±³          ³ Lj7T_Array(1, 1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_Array( nLinha, nColuna, uParam )

If uParam = Nil
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Retorna os valores											 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Return aTotais[nLinha, nColuna]
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Altera os valores e da o refresh							 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aTotais[nLinha, nColuna] := uParam

	If nColuna = 1
		If aTotais[nLinha, 5] <> Nil
			aTotais[nLinha, 5]:Refresh()
		Endif
	ElseIf nColuna <> 3
		If aTotais[nLinha, 3] <> Nil
			aTotais[nLinha, 3]:Refresh()
		Endif
	EndIf
EndIf
Return (NIL)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7R_Rodape³ Autor ³ Vendas Clientes      ³ Data ³ 11/03/03 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Mensagem no Rodape da tela de venda                   	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ cExp1 - Mensagem do Rodape   		                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7R_Rodape(cMensagem)

If ValType( cMensagem ) == "C" .AND. !isBlind()
	aRodape[1, 1] := cMensagem
	aRodape[1, 2]:Refresh()
EndIf

Return (NIL)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_VlTp ³ Autor ³ Vendas Clientes      ³ Data ³ 04/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Valida se o tipo do total que sera manipulado e valido	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_VlTp(nExp1, cExp2, uExp3)		                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Tipo que deve ser validado						  ³±±
±±³          ³ cExp2 - Nome da funcao									  ³±±
±±³          ³ uExp3 - Qual valor deve conter							  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_VlTp( nIndice, cNomFun, uValor )
Local lRet		:= .T.									// Retorno da funcao
Local cFunc		:= Substr( cNomFun, 7, Len(cNomFun) )	// Nome reduzido da funcao
Local lAutoExA	:= IsBlind()							// Verifica se a rotina sera executada via execauto ou nao

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Total de opcoes disponiveis.								 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nIndice <= 0 .OR. nIndice > Len(aFuncoes)
	If !lAutoExA
		Aviso(	STR0006,; //"Inconsistencia"
				STR0007 + cNomFun + STR0014 + "[" + AllTrim(str(nIndice)) + "]" + CRLF +; //"Esta sendo enviado para a funcao "###" um INDICE que nao existe."
				STR0009 + CRLF +; //"Isto podera ocasionar um erro no sistema."
				STR0010, {STR0003}) //"Verifique o 1o parametro dessa funcao"###"OK"
	Else
		ConOut(STR0007 + cNomFun + STR0014 + "[" + AllTrim(str(nIndice)) + "]" + CRLF + STR0009 + CRLF + STR0010)
	EndIf
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se o parametro para atualizacao nao e NIL entao precisa ser	 ³
//³ avaliado se o tipo X parametro sao compativeis				 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If uValor <> Nil
	Do Case
		Case Upper(cFunc) $ "TITU|DICA|IMAG|FUNC"	.AND. ValType( uValor ) <> "C"
			lRet := .F.

		Case Upper(cFunc) $ "GRUP"				.AND. ValType( uValor ) <> "N"
			lRet := .F.

		Case Upper(cFunc) $ "TBAR|MENU"			.AND. ValType( uValor ) <> "L"
			lRet := .F.

		Case Upper(cFunc) $ "SKEY" .AND. ValType( uValor ) <> "A" .AND. len(uValor) <> 2
			lRet := .F.
	EndCase
EndIf

If !lRet
	If !lAutoExA
		Aviso(	STR0006,; //"Inconsistencia"
				STR0007 + cNomFun + STR0011 + CRLF+; //"Esta sendo enviado para a funcao "###" um TIPO incompativel"
				STR0012 + CRLF +; //"com o valor a ser recebido."
				STR0009 + CRLF +; //"Isto podera ocasionar um erro no sistema."
				STR0013, {STR0003}) //"Verifique o - 2o parametro dessa funcao"###"OK"
	Else
		ConOut(STR0007 + cNomFun + STR0011 + CRLF+ STR0012 + CRLF + STR0009 + CRLF + STR0013)
	EndIf
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Titu ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo manipular o titulo das opcoes de menu. 		 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Titu(nExp1, cExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao 					 		 		  ³±±
±±³          ³ cExp2 - Titulo desejado									  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Titu( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "Lj7F_Titu", uParam )
	Return .F.
EndIf

Return Lj7F_Array( nIndice, 1, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Dica ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo manipular a Dica (tip) do botao. 			 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Dica(nExp1, cExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao 					 		 		  ³±±
±±³          ³ cExp2 - Dica (mensagem) desejada							  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Dica( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "Lj7F_Dica", uParam )
	Return .F.
EndIf

Return Lj7F_Array( nIndice, 2, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Imag ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo manipular a imagem (resource) do botao. 		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Imag(nExp1, cExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao 					 		 		  ³±±
±±³          ³ cExp2 - Nome da imagem desejada							  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Imag( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "Lj7F_Imag", uParam )
	Return .F.
EndIf

Return Lj7F_Array( nIndice, 3, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Func ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo manipular a funcao (resource) a ser executada.	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Func(nExp1, cExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao 					 		 		  ³±±
±±³          ³ cExp2 - Nome e parametros a ser executado				  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Func( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "Lj7F_Func", uParam )
	Return .F.
EndIf

Return Lj7F_Array( nIndice, 4, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_TBar ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo habilitar ou desabilitar a apresentacao da 		  ³±±
±±³          ³ funcao na Toolbar										  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_TBar(nExp1, lExp2)                                    ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao                                    ³±±
±±³          ³ lExp2 -                                                    ³±±
±±³          ³ .T. - Habilita na toolbar                                  ³±±
±±³          ³ .F. - Desabilita na toolbar                                ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_TBar( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "Lj7F_TBar", uParam )
	Return .F.
EndIf

Return Lj7F_Array( nIndice, 6, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Menu ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo habilitar ou desabilitar a apresentacao da 		  ³±±
±±³          ³ funcao no menu											  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Menu(nExp1, lExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao 					 		 		  ³±±
±±³          ³ lExp2 - 													  ³±±
±±³          ³ .T. - Habilita opcao no menu								  ³±±
±±³          ³ .F. - Desabilita opcao no menu							  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Menu( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "Lj7F_Menu", uParam )
	Return .F.
EndIf

Return Lj7F_Array( nIndice, 6, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Grup ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo manipular o grupo o qual a funcao pertence.		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Menu(nExp1, nExp2)				                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Indice da opcao 					 		 		  ³±±
±±³          ³ nExp2 - No do grupo 										  ³±±
±±³          ³ 1 - Salvar												  ³±±
±±³          ³ 2 - Detalhar												  ³±±
±±³          ³ 3 - Produtos												  ³±±
±±³          ³ 4 - Util													  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Grup( nIndice, uParam )

Local lAutoExA := IsBlind()		// Verifica se a rotina sera executada via execauto ou nao

If !Lj7F_VlTp ( nIndice, "Lj7F_Grup", uParam )
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ O valor 4 representa o total de grupos de opcao do menu.	 ³
//³ Esta quantidade SOMENTE deve ser alterada pela equipe de 	 ³
//³ desenvolvimento.											 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If uParam <> NIL .AND. uParam >= 5
	If !lRet
		If !lAutoExA
			Aviso(	STR0006,; //"Inconsistencia"
					STR0015 + CRLF +; //"Esta sendo enviado para a funcao Lj7F_Grup um VALOR maior"
					STR0016 + CRLF +; //"do que o total de grupos disponiveis para o menu."
					STR0009 + CRLF +; //"Isto podera ocasionar um erro no sistema."
					STR0013, {STR0003}) //"Verifique o - 2o parametro dessa funcao"###"OK"
		Else
			ConOut(STR0015 + CRLF + STR0016 + CRLF + STR0009 + CRLF + STR0013)
		EndIf
		Return .F.
	EndIf
EndIf

Return Lj7F_Array( nIndice, 7, uParam )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7F_SetKeºAutor  ³ Vendas Clientes    º Data ³  05/10/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Altera o array aFuncoes                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpN1 - Tipo que deve ser validado                          º±±
±±º          ³ExpU2 - Qual valor deve conter                              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7F_SetKey( nIndice, uParam )

If !Lj7F_VlTp ( nIndice, "LJ7F_SKey", uParam )
	Return .F.
EndIf

Lj7F_Array( nIndice, 8, uParam )

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7F_Salva³ Autor ³ Vendas Clientes      ³ Data ³ 17/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Salvar ou restaurar o conteudo original do array aFuncoes. ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Salva(lExp1)					                 	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ lExp1 - 				 					 		 		  ³±±
±±³          ³ T - Salva a posicao atual								  ³±±
±±³          ³ F - Restaura a posicao atual								  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Salva( lSalva )
Static aFuncOri						// Contem o array aFuncoes original
Default lSalva := .T.

If lSalva
	aFuncOri := aClone(aFuncoes)		// Salva
Else
	aFuncoes := aClone(aFuncOri)		// Restaura
EndIf
Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³Lj7F_Array ³ Autor ³ Vendas Clientes      ³ Data ³ 16/07/02 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Popup Menu, tem como	  ³±±
±±³          ³ objetivo manipular o array aFuncoes					  	  ³±±
±±³          ³ 														  	  ³±±
±±³          ³ Esta e a unica funcao que deve ALTERAR diretamente o array ³±±
±±³          ³ aFuncoes.												  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7F_Array(nExp1, nExp2, uExp3)		                  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - Linha a ser manipulada					 		  ³±±
±±³          ³ nExp2 - Coluna ser manipulada					 		  ³±±
±±³          ³ uExp3 - Valor a ser recebido								  ³±±
±±³          ³ 															  ³±±
±±³          ³ Consulte LOJA701.prw para verificar o aFuncoes PADRAO	  ³±±
±±³          ³ Para nExp1, tem-se										  ³±±
±±³          ³ 															  ³±±
±±³          ³  1 - Gravar como orcamento								  ³±±
±±³          ³  2 - Como venda											  ³±±
±±³          ³  3 - Sair												  ³±±
±±³          ³  4 - Pagamento											  ³±±
±±³          ³  5 - Item												  ³±±
±±³          ³  6 - Frete												  ³±±
±±³          ³  7 - Cliente												  ³±±
±±³          ³  8 - Efetuar reserva										  ³±±
±±³          ³  9 - Consultar reserva									  ³±±
±±³          ³ 10 - Consultar estoque									  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp2, tem-se:										  ³±±
±±³          ³ 1 - Titulo para o menu									  ³±±
±±³          ³ 2 - Titulo para botao (tip)                                ³±±
±±³          ³ 3 - Resource										  		  ³±±
±±³          ³ 4 - Funcao a ser executada								  ³±±
±±³          ³ 5 - Aparece na toolbar lateral ? (TRUE / FALSE)			  ³±±
±±³          ³ 6 - Habilitada ? (TRUE / FALSE)							  ³±±
±±³          ³ 7 - Grupo	(1- Gravacao, 2- Detalhes, 					  ³±±
±±³          ³ 				 3- Estoque, 4- Outros)						  ³±±
±±³          ³ 8 - Array com: [1] - o atalho (setkey) do botao            ³±±
±±³          ³                [2] - Texto do atalho                       ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do Gravar como Orcamento	  		  ³±±
±±³          ³ Lj7F_Array(1, 1, "Orcamento")							  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo do sub-total:						  ³±±
±±³          ³ Lj7T_Array(1, 1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7F_Array( nLinha, nColuna, uParam )
Local nCount1	:= 0			// Contador 1
Local nCount2 	:= 0			// Contador 2
Local aFunc		:= {}			// Array que contem o No do botao correspondente a funcao
Local nLinBot	:= 0			// Linha do botao

If uParam == Nil
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Retorna os valores											 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (nColuna == 1 .OR. nColuna == 2) .AND. !(" ("+ aFuncoes[nLinha][8][2] + ")" $ aFuncoes[nLinha, nColuna] )
		Return aFuncoes[nLinha, nColuna] + " (" + aFuncoes[nLinha][8][2] + ")"
	Else
		Return aFuncoes[nLinha, nColuna]
	Endif
Else

	If nColuna == 6	// Habilita funcao no menu
		//Se vai habilitar a funcao no menu, verifica se eh uma funcao que nao deve ser habilitada de acordo com o Ponto de Entrada "LJNoFunc".
		If uParam .And. lLj7IsNoFun
			If Lj7IsNoFun(nLinha)
				uParam := .F. //Se eh uma funcao que deve ser desabilitada, entao altera para .F. (false)
			EndIf
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Altera os valores 											 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	aFuncoes[nLinha, nColuna] := uParam
	If nColuna == 2 .OR. nColuna == 6
		nCount2 := Len(aFuncoes)
		For nCount1 := 1 To nCount2
			aAdd(aFunc, 0)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Aparece na toolbar, entao incrementa a posicao do botao		 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aFuncoes[nCount1, 5]
				nLinBot ++
				aFunc[nCount1] := nLinBot
			EndIf
		Next nCount1

		If nColuna == 2			// Dica do botao
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Atualiza o tip do botao										 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aFunc[nLinha] > 0
				aBotTB[aFunc[nLinha]]:cToolTip := uParam
			EndIf

		ElseIf nColuna == 6		// Habilita funcao no menu
			Default uParam := .T.
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Habilita ou desabilita as funcoes de atalho.                 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !uParam
				// Desabilita a tecla de atalho
				SetKey(aFuncoes[nLinha][8][1], {|| nil})
			Else
				// Habilita a tecla de atalho
				SetKey(aFuncoes[nLinha][8][1], aFuncoes[nLinha][4])
			Endif

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ A opcao aparece na toolbar ? Entao o botao deve ser  		 ³
			//³ manipulado tambem										 	 ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If aFuncoes[nLinha][5] .AND. ValType(aBotTB[aFunc[nLinha]]) == "O"
				If !uParam
					aBotTB[aFunc[nLinha]]:Disable()
				Else
					aBotTB[aFunc[nLinha]]:Enable()
				EndIf
			EndIf
		EndIf
	EndIf
EndIf
Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7AliqIcmsºAutor ³ Vendas Clientes    º Data ³  19/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Retorna a aliquota de ICMS                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpN1 := Lj7AliqIcms( ExpC1, ExpA1, ExpC2 )                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Codigo do produto                                   º±±
±±º          ³ExpA1 - Array com as informacoes do cliente                 º±±
±±º          ³        [1] - Codigo do cliente                             º±±
±±º          ³        [2] - Loja                                          º±±
±±º          ³ExpC2 - Codigo do TES que estah sendo utilizado             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpN1 - Aliquota de ICMS                                    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7AliqIcms( cProduto, aCliente, cTes )
Local nPerRet 	:= 0											// Percentual de ICMS (aliquota)

Default cTes	:= SuperGetMV("MV_TESSAI",,"501")				// Pega do parametro o TES padrao para saida

SB1->(DbSeek(xFilial("SB1")+cProduto))
SA1->(DbSeek(xFilial("SA1")+aCliente[1]+aCliente[2]))
SF4->(DbSeek(xFilial("SF4")+cTES))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Caso Calcule Icms  Chama a Funcao do FISXFUN.PRX para retornar ³
//³ a Aliquota correta para c lculo do Icms                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
IF SF4->F4_ICM == "S"
	nPerRet := AliqIcms("N","S",SA1->A1_TIPO,"I")
EndIf

Return nPerRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7GetAreaºAutor  ³ Vendas Clientes    º Data ³  19/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Guarda a area de trabalho                                   º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := Lj7GetArea( ExpA2 )                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpA2 - Array com os aliases que devem ser guardados.       º±±
±±º          ³        Exemplo: {"SL1","SL2"}                              º±±
±±º          ³                                                            º±±
±±º          ³        Se ExpA2 == Nil ira guardar apenas da area corrente º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpA1 - Array com a area de trabalho                        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Generico                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7GetArea( aArea )
Local aRet 		:= {}				// Array de retorno com os dados das areas de trabalho
Local nX		:= 0				// Auxiliar de loop
Default aArea	:= { Alias() }		// Area de trabalho atual

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Armazena os aliases solicitados e por ultimo o alias corrente  ³
//³ para sempre manter a area de trabalho mesmo se o alias corrente³
//³ nao for passado como parametro                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 to Len( aArea )
	aAdd( aRet, { aArea[nX], &(aArea[nX]+"->(IndexOrd())"), &(aArea[nX]+"->(Recno())") } )
Next nX

If !Empty(Alias())
  aAdd( aRet, { Alias(), IndexOrd(), Recno() } )
EndIf

Return aRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7RestAreaºAutor ³ Vendas Clientes    º Data ³  19/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Restaura a area de trabalho                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Void Lj7RestArea( ExpA1 )                                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpA1 - Array contendo as informacoes para restaurar a area º±±
±±º          ³        de trabalho.                                        º±±
±±º          ³        A variavel ExpA1 e alimentada atraves da Lj7GetArea º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Generico                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7RestArea( aArea )
Local nX := 0	// controle de loop

If aArea <> Nil
	For nX := 1 to Len(aArea)
		If !Empty(aArea[nX][1])
			&(aArea[nX][1]+"->(DbSetOrder( "+StrZero(aArea[nX][2],2,0)+" ))")
			If &(aArea[nX][1]+"->(Recno())") <> aArea[nX][3]
				&(aArea[nX][1]+"->(dbGoTo( "+AllTrim(Str(aArea[nX][3]))+" ))")
			Endif
	    EndIf
	Next nX

	DbSelectArea( aArea[Len(aArea)][1] )
	DbSetOrder( aArea[Len(aArea)][2] )
	If aArea[Len(aArea)][3] <> Recno()
		dbGoTo( aArea[Len(aArea)][3] )
	Endif
Endif

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7VldDescºAutor  ³ Vendas Clientes    º Data ³  03/09/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a validacao do desconto no total da venda               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpL1 := LJ7VldDesc()                                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpO1 - Objeto do painel de recebimentos                    º±±
±±º          ³ExpN2 - Valor do desconto a ser considerado sem interface   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpL1 - Permite ou nao efetuar o desconto                   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7VldDesc( oPanVA3, nPercDesc, nValorDesc )
Local lRet 			:= .T.																			// Indica o retorno da funcao
Local lConfirma		:= .F.																			// Indica se o usuario confirmou ou nao o descto
Local nPerDesc	 	:= 0																			// Percentual de Desconto
Local nVlrDesc		:= 0																			// Valor do desconto
Local nX			:= 0																			// Usada em lacos For...Next
Local nVlrAux 		:= 0																			// Usada para totalizar o valor das parcelas
Local nVlrMerc		:= 0																			// Valor total das mercadorias
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]		// Posicao do Valor Total do Item

Local oDlgDesconto																					// Objeto de montagem de desconto no total
Local oPerDesc																						// Objeto para receber o desconto percentual no total
Local oVlrDesc																						// Objeto para receber o desconto em valor no total
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]		// Posicao da codigo do produto
Local oDesconto																						// Instancia o objeto que fara o desconto
Local nMvLjTpDes	:= SuperGetMv("MV_LJTPDES", , 0)												// Indica qual desconto sera' utilizado 0 - Antigo / 1 - Novo (objeto)
Local cTipoDesc     := SuperGetMV("MV_LJTIPOD",.F.,"1")												// Tipo do Desconto para validacao da permissao
Local cTesSai  		:= SuperGetMV("MV_TESSAI",,"501")												// Pega do parametro o TES padrao para saida
Local cTesPad       := ""																			// Codigo da TES
Local nValSol		:= 0																			// Recebe o Valor total da substituição tributária
Local nPosDtTes		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})						// Posicao do Codigo do TES
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]		// Posicao do valor de desconto
Local nVlrDescBkp	:= 0																			// Valor Backup do desconto
Local cTesInt		:= ""																			// Codigo do Tes de saida
Local lExibeTela	:= .T.																			// Indica se a tela de desconto sera exibida
Local nPosPrcTab	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_PRCTAB"})					// Posicao do preco de tabela
Local nPosQtda  	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_QUANT"})][2]			// Posicao da quantidade
Local nPosVrUnit	:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VRUNIT"})][2]			// Posicao do Valor unitario
Local nVlrComp		:= 0																			// compara valor para atualizar aPgtos
Local lMvAjstDes 	:= SuperGetMV( "MV_LJAJDES",,.F. )												// Verifica parametro ajuste de desconto no total da venda
Local lAutoExA		:= IsBlind()																	// Verifica se a rotina sera executada via execauto ou nao
Local lMargem       := SuperGetMV("MV_LJMARGE",,.F.) 				            					// Valida se considera a margem minIma no venda assistida.
//³Release 11.5 - Localizacoes ³
Local lLocR5		:= cPaisLoc$"CHI|COL"
Local aLJ7104		:= {}  																			// Array para retorno do Ponto de Entrada LJ7104
Local nNF_ValIpi	:= 0																			// Valor do IPI da nota conforme a MATXFIS	
Local nIT_ValIpi    := 0																			// Valor do IPI do item conforme a MATXFIS
Local nPosPgtoPBM	:= 0																			// Posição do pagamento adicionado do PBM Funcional Card
Local aPgtoPBM		:= {}																			// Backup do pagamento do PBM Funcional Card
Local nPosTesInt	:= 0
Local lLJ7107		:= ExistBlock("LJ7107")
Local aLJ7107		:= {0, 0}
Local lMvArrefat    := SuperGetMv("MV_ARREFAT") == "S"
Local lIntegDef  	:= If(Type("lAutoExec") == "L", lAutoExec,.F.) .And. FWHasEAI("LOJA701",, .T., .T.) .AND. IIF( ExistFunc("Lj701GtInD") , Lj701GtInD(), IsInCallStack("LOJI701"))  //Integracao via Mensagem Unica
Local lPBMDesc		:= ExistTemplate("DroPbmDe") .AND. T_DroPbmDe()

Default nPercDesc   := 0    // Percentual de desconto
Default nValorDesc  := 0	// Valor de desconto

If Empty(aCols[n][nPosProd]) .OR. aCols[n][nPosVrUnit] == 0
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se a rotina foi acionada atraves de outra funcao,		 ³
//³ou via ExecAuto, recebendo o percentual do desconto como parametro³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lCenVenda .OR. lAutoExec

	If (nPercDesc <> Nil) .AND. ValType(nPercDesc) == "N" .AND. nPercDesc > 0
		lExibeTela		:= .F.
		nPerDesc		:= nPercDesc
		lConfirma		:= .T.
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica se a rotina foi acionada atraves de outra funcao,³
	//³recebendo o valor do desconto como parametro              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (nValorDesc <> Nil) .AND. ValType(nValorDesc) == "N" .AND. nValorDesc > 0
		lExibeTela		:= .F.
		nVlrDesc		:= nValorDesc
		lConfirma		:= .T.
	EndIf

EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Caso o parametro esteja com 1, inicializa o objeto de ³
//³desconto.                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nMvLjTpDes == 1 .OR. nMvLjTpDes == 2
	oDesconto := Desconto():New()
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifico se o Profile do usuario permite que execute descontos           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lExibeTela .AND. ( !LjProfile( 11 ) )
	lRet := .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o caixa pode executar descontos quando a integracao³
//³com o cenario de vendas esta ativa                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. lExibeTela .AND. lCenVenda .AND. !LjOpcDesc()
	If lAutoExA
		Conout(STR0053)
	Else
		MsgStop(STR0053) //"Não é permitido alterar o desconto atribuido pela regra de descontos, conforme a configuração do caixa atual."
	Endif
	lRet := .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Desabilita o desconto na tela de pagamentos.³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If oPanVA3 == Nil
	lExibeTela := .F.
Endif

If lExibeTela .AND. ValType(oPanVA3) == "O" .AND. oPanVA3:lVisibleControl
	lRet := .F.
EndIf

If LJAnalisaLeg(41)[1]
	For nX := 1 to Len( aCols )
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Se a linha nao estiver deletada³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If !aCols[nX][Len(aCols[nx])]
			If aCols[nX][nPosValDesc] > 0
				If lExibeTela .AND. !lAutoExA
					LJMsgLeg( LJAnalisaLeg(41) )
				EndIf
				Return lRet
			EndIf
		EndIf
	Next nX
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Nao permite efetuar desconto caso o valor da da venda        ³
//³ seja = 0 (zero)                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Lj7T_Total( 2 ) <> 0 .AND. lRet
	nNF_ValIpi	:= Iif( MaFisFound("NF") , MaFisRet(,"NF_VALIPI") , 0 )
	SF4->( DbSetOrder( 1 ) )
	
	For nX := 1 To Len(aCols)
	
		If !aCols[nX][Len(aCols[nx])] .And. MaFisFound("IT",nX)
		
			If nNF_ValIpi > 0 .And. MaFisRet( nX, "IT_VALIPI" ) > 0
				MaFisAlt("IT_BASEIPI", aCols[nX][nPosVlItem], nX )
				nIT_ValIpi += MaFisRet(nX,"IT_VALIPI")
		    EndIf
			
			//--------------------------------------------------------------------------------------
			//Laco para ler todos os itens do aCols e somar o imposto solidario caso seja agregado
			//-------------------------------------------------------------------------------------
			//---------------------------------------------
			//³Parametro da funcao MaTesInt               ³
			//³ExpN1 = Documento de 1-Entrada / 2-Saida   ³
			//³ExpC1 = Tipo de Operacao Tabela "DF" do SX5³
			//³ExpC2 = Codigo do Cliente ou Fornecedor    ³
			//³ExpC3 = Codigo do gracao E-Entrada         ³
			//³ExpC4 = Tipo de Operacao E-Entrada         ³
			//---------------------------------------------			
			//-----------------------------------------------------------------------------------------------
			// Tratamento para pegar as informações da Tes Inteligente no array estatico caso já tenha sido 
			// consultado na função MaTesInt anteriormente, para melhoria de performance no venda assistida.
			//-----------------------------------------------------------------------------------------------
			nPosTesInt := aScan(aTesInt, {|x| x[1] + x[2] + x[3] == M->LQ_CLIENTE + M->LQ_LOJA + aCols[n][nPosProd] } )
			If nPosTesInt > 0
				cTesInt := aTesInt[nPosTesInt][4]
			Else
				cTesInt := MaTesInt( 2	, "01"					, M->LQ_CLIENTE	, M->LQ_LOJA,;
								 	"C"	, aCols[nX][nPosProd]	, NIL			)
				
				aAdd(aTesInt, { M->LQ_CLIENTE, M->LQ_LOJA, aCols[n][nPosProd], cTESInt } )
				SF4->( DbSetOrder( 1 ) )
			EndIf
			
			If !Empty(cTesInt)
				cTesPad := cTesInt
			Else
				If ValType( aColsDet ) == "A" .AND. Len( aColsDet ) >= nX .AND. !("LR_PRODUTO"$ReadVar())
					cTesPad := aColsDet[nX][nPosDtTes]
				Else
					cTesPad := If( Empty( RetFldProd( SB1->B1_COD,"B1_TS" ) ), cTesSai, RetFldProd( SB1->B1_COD,"B1_TS" ) )
				Endif
			Endif

			// Verifica se o TES agrega a substituição tributaria
			If SF4->(DbSeek(xFilial("SF4")+cTesPad)) .And. SF4->F4_INCSOL == "S"
				nValSol	+= MaFisRet(nX,"IT_VALSOL")
			EndIf
		EndIf
	Next nX

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Desabilita as teclas de atalho                                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.F.)

 	If lExibeTela 
		
		/*Ponto de entrada LJ7107, responsavel por permitir a atuacao no desconto do total, 
		levando em consideração possível aplicação anterior de acréscimo financeiro 
		via condicao de pagamento na mesma venda.*/
		If lLJ7107
			LjGrvLog(NIL,"Antes da Execução do P.E. LJ7107",{ Lj7T_Total(2), aPgtos, aDesconto })
			aLJ7107 := ExecBlock("LJ7107", .F., .F., { Lj7T_Total(2), aPgtos, aDesconto } )
			LjGrvLog(NIL,"Depois da Execução do P.E. LJ7107",aLJ7107)
			If ValType(aLJ7107) == "A" .And. Len(aLJ7107) == 2 .And.;
				Valtype(aLJ7107[1]) == "N" .And. Valtype(aLJ7107[2]) == "N" .And. aLJ7107[1] > 0
				
				nPerDesc := aLJ7107[1]
				nVlrDesc := aLJ7107[2]
				LjGrvLog("", "Ponto de Entrada LJ7107 executado e gerou o seguinte retorno: ", aLJ7107)
			Else
				LjGrvLog("", "Ponto de Entrada LJ7107 conforme documentação TDN, retornou valor incompatível  com a variavel esperada: ", aLJ7107)	
			EndIf	
		EndIf

 		If !lAutoExA
			DEFINE MSDIALOG oDlgDesconto FROM 0,0 TO 113,285 TITLE STR0017 PIXEL //"Desconto no Total da Venda"
			@ 6, 04 BITMAP RESOURCE "DISCOUNT" OF oDlgDesconto PIXEL SIZE 32,32 ADJUST When .F. NOBORDER
			@ 04, 40 TO 38, 140 PIXEL OF oDlgDesconto
	
			@ 11, 45 SAY STR0018 PIXEL OF oDlgDesconto //"% Desconto"
			@ 21, 45 MSGET oPerDesc VAR nPerDesc 	SIZE 35,10 ;
													OF oDlgDesconto PICTURE "@E 99.99" RIGHT PIXEL ;
													VALID IIf( nPerDesc < 0, ( MsgStop(STR0038), .F. ), .T. ) //"Valor não permitido para esse campo."
		EndIf

		If cPaisLoc == "BRA"
	    	If nMvLjTpDes == 0
		    	If lMvArrefat
                    oPerDesc:bLostFocus := { || nVlrDescBkp	:= nVlrDesc := Round((Lj7T_Total(2) + Lj7T_DescV(2) - nValSol - nIT_ValIpi) * nPerDesc / 100, nDecimais ), oVlrDesc:Refresh(), lConfirma := .F.}
                Else
                    oPerDesc:bLostFocus := { || nVlrDescBkp := nVlrDesc := NoRound((Lj7T_Total(2) + Lj7T_DescV(2) - nValSol - nIT_ValIpi) * nPerDesc / 100, nDecimais ), oVlrDesc:Refresh(), lConfirma := .F.}
                EndIf
	    	Else
	    		If lMvAjstDes
					oPerDesc:bLostFocus := { || nVlrDescBkp	:= nVlrDesc := oDesconto:TotalValor( (Lj7T_Total(2) - nIT_ValIpi), Lj7T_DescV(2), nPerDesc ), nPerDesc := oDesconto:TotalPercent( (Lj7T_Total(2) - nIT_ValIpi), Lj7T_DescV(2), nVlrDesc)  }
				Else
					oPerDesc:bLostFocus := { || nVlrDescBkp	:= nVlrDesc := oDesconto:TotalValor( (Lj7T_Total(2) - nIT_ValIpi), Lj7T_DescV(2), nPerDesc )}
				EndIf
	   	    Endif
	   	Else
		
			nVlrMerc := Lj7T_Total(2) - Lj7T_ImpsV("1",2) + Lj7T_DescV(2)
			If nMvLjTpDes == 0
				oPerDesc:bLostFocus := { || nVlrDescBkp	:= nVlrDesc := Round(nVlrMerc*nPerDesc/100,nDecimais), oVlrDesc:Refresh(), lConfirma := .F. }
			Else
				oPerDesc:bLostFocus := { || nVlrDescBkp	:= nVlrDesc := Lj701ValDes(nVlrMerc , Lj7T_DescV(2), nPerDesc , @oDesconto ) }
			EndIf
		EndIf

		@ 11, 87 SAY STR0019 PIXEL OF oDlgDesconto //"Vlr.Desconto"

		If lLocR5
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Release 11.5 - Localizacoes                           ³
			//³Picture do campo de valor de desconto de acordo com a ³
			//³mascara do campo L1_DESCONT                           ³
			//³Paises : Chile / Colombia  - F1CHI                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			@ 21, 87 MSGET oVlrDesc VAR nVlrDesc SIZE 50,10 OF oDlgDesconto PICTURE PesqPict("SL1", "L1_DESCONT",11,nMoedaCor) RIGHT PIXEL ;
			VALID IIf( nVlrDesc < 0, ( MsgStop(STR0038), .F. ), .T. ) .AND. ; 		//"Valor não permitido para esse campo."
		      IIf( nVlrDesc >= Lj7T_Total( 2 ), ( MsgStop(STR0043), .F. ), .T. )//"O valor do desconto é maior ou igual ao valor da venda, favor verificar!"
		Else
			@ 21, 87 MSGET oVlrDesc VAR nVlrDesc SIZE 50,10 OF oDlgDesconto PICTURE "@E 999,999,999.99" RIGHT PIXEL ;
			VALID IIf( nVlrDesc < 0, ( MsgStop(STR0038), .F. ), .T. ) .AND. ; 		//"Valor não permitido para esse campo."
	      	IIf( nVlrDesc >= Lj7T_Total( 2 ), ( MsgStop(STR0043), .F. ), .T. ) .AND. ;//"O valor do desconto é maior ou igual ao valor da venda, favor verificar!"
			IIf( !lMargem .OR. (lMarGem .AND.  LJ7VldMarg(nVlrDesc)),.T.,.F. )
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³So' recalcula caso o percentual do desconto for zerado. ³
		//³E se o valor de desconto for modificado pelo o usuario. ³
		//³Evita que por problemas de arredondamento exiba valor   ³
		//³percentual incorreto.                                   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cPaisLoc == "BRA"
			If nMvLjTpDes == 0
				oVlrDesc:bLostFocus := { || If( nPerDesc == 0 .OR. ( nVlrDescBkp <> nVlrDesc ), (nPerDesc := Round(nVlrDesc*100/(Lj7T_Total(2) + Lj7T_DescV(2) - nValSol - nIT_ValIpi),nDecimais),;
												nVlrDescBkp := nVlrDesc, oPerDesc:Refresh(), lConfirma := .F.), Nil )}
			Else
				If lMvAjstDes
					oVlrDesc:bLostFocus := { || If( nPerDesc == 0 .OR. ( nVlrDescBkp <> nVlrDesc ), (nPerDesc := oDesconto:TotalPercent( (Lj7T_Total(2) - nIT_ValIpi), Lj7T_DescV(2), nVlrDesc),;
													nVlrDescBkp := nVlrDesc, oPerDesc:Refresh(), nVlrDescBkp := nVlrDesc := oDesconto:TotalValor( (Lj7T_Total(2)- nIT_ValIpi), Lj7T_DescV(2), nPerDesc ), lConfirma := .F.), Nil ) }
				Else
					oVlrDesc:bLostFocus := { || If( nPerDesc == 0 .OR. ( nVlrDescBkp <> nVlrDesc ), (nPerDesc := oDesconto:TotalPercent( (Lj7T_Total(2)- nIT_ValIpi), Lj7T_DescV(2), nVlrDesc),;
													nVlrDescBkp := nVlrDesc, oPerDesc:Refresh(), lConfirma := .F.), Nil ) }
				EndIf
			EndIf
		Else
			nVlrMerc := Lj7T_Total(2) - Lj7T_ImpsV("1",2) + Lj7T_DescV(2)
			If nMvLjTpDes == 0
				oVlrDesc:bLostFocus := { || If( nPerDesc == 0, ( nPerDesc := Round(nVlrDesc*100/nVlrMerc,nDecimais), oPerDesc:Refresh(), lConfirma := .F.,;
												     nVlrDescBkp := nVlrDesc ,	oPerDesc:Refresh(), lConfirma := .F.     ) , Nil ) }
			Else
				oVlrDesc:bLostFocus := { || If( nPerDesc == 0 .OR. ( nVlrDescBkp <> nVlrDesc ), ( nPerDesc := oDesconto:TotalPercent( Lj7T_Total(2) - Lj7T_ImpsV("1",2), Lj7T_DescV(2), nVlrDesc ),;
											    	nVlrDescBkp := nVlrDesc ,	oPerDesc:Refresh(), lConfirma := .F.     ) , Nil ) }
	    	EndIf
	    EndIf

		DEFINE SBUTTON FROM 40, 083 TYPE 1 ENABLE OF oDlgDesconto ;
		ACTION (lConfirma := .T., oDlgDesconto:End()) PIXEL		//Botao OK

		DEFINE SBUTTON FROM 40, 113 TYPE 2 ENABLE OF oDlgDesconto ;
		ACTION ((lConfirma := .F., 	nPerDesc := 0, nVlrDesc:= 0), oDlgDesconto:End()) PIXEL	//Botao Cancelar

		ACTIVATE MSDIALOG oDlgDesconto ;
		VALID Lj7VldServ() .And. LJ7_ValDesc(Val(cTipoDesc), nPerDesc, nVlrDesc);
		CENTERED

	Else
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Calcula o valor do desconto quando nao ha interface³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If (nPercDesc <> Nil) .AND. ValType(nPercDesc) == "N" .AND. nPercDesc > 0
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Calculo a partir do percentual³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cPaisLoc == "BRA"
				If nMvLjTpDes == 0
					nVlrDesc := Round((Lj7T_Total(2) + Lj7T_DescV(2) - nValSol - nIT_ValIpi) * nPerDesc / 100, nDecimais )
				Else
					nVlrDesc := oDesconto:TotalValor( (Lj7T_Total(2) - nIT_ValIpi), Lj7T_DescV(2), nPerDesc )
				Endif
			Else
				nVlrMerc := Lj7T_Total(2) - Lj7T_ImpsV("1",2) + Lj7T_DescV(2)
				nVlrDesc := Round(nVlrMerc*nPerDesc/100,nDecimais)
			EndIf

		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Calculo a partir do valor ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cPaisLoc == "BRA"
				If nMvLjTpDes == 0
					If nPerDesc == 0 .OR. ( nVlrDescBkp <> nVlrDesc )
						nPerDesc := Round(nVlrDesc*100/(Lj7T_Total(2) +Lj7T_DescV(2)),nDecimais)
						nVlrDescBkp := nVlrDesc
					EndIf
				Else
					If nPerDesc == 0 .OR. ( nVlrDescBkp <> nVlrDesc )
						nPerDesc := oDesconto:TotalPercent( Lj7T_Total(2), Lj7T_DescV(2), nVlrDesc)
						nVlrDescBkp := nVlrDesc
					EndIf
				EndIf
			Else
				nVlrMerc := Lj7T_Total(2) - Lj7T_ImpsV("1",2) + Lj7T_DescV(2)
				If nPerDesc == 0
					nPerDesc := Round(nVlrDesc*100/nVlrMerc,nDecimais)
				EndIf
			EndIf

   		EndIf

	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita as teclas de atalho                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.T.)
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Chamada o Ponto de LJ7104 para que o Usuario possa modificar o   ³
//³Ratiando o Desconto total entre os itens conforme sua necessidade³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock( "LJ7104" )
	LjGrvLog( NIL, "Antes da Execução do P.E. LJ7014",{nPerDesc ,nVlrDesc})
	aLJ7104 :=ExecBlock( "LJ7104", .F., .F., {nPerDesc ,nVlrDesc} )
	LjGrvLog( NIL, "Depois da Execução do P.E. LJ7014",aLJ7104)
	If ValType(aLJ7104) == "A" .And. Len(aLJ7104) > 0 .And. VldLJ7104( aLJ7104,nPerDesc,nVlrDesc )
		LJ7AplDesc(aLJ7104)
		nPerDesc := 0
		nVlrDesc := 0
	Else
		LjGrvLog( NIL, "Retorno inválido do P.E. LJ7014 ")
	EndIf
EndIf

If lConfirma
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Zera o desconto no total apenas se foi informado depois da condicao ³
	//³ de pagamento                                                        ³
	//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
	//³ Verifica se o desconto esta sendo chamado antes ou depois de        ³
	//³ informar a condicao de pagamento                                    ³
	//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
	//³ aDesconto[1] := 0	// Nao tem desconto                             ³
	//³ aDesconto[1] := 1	// Antes da condicao de pagamento               ³
	//³ aDesconto[1] := 2	// Depois da condicao de pagamento              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nVlrAux := 0
	
	If !lPBMDesc .AND. ExistTemplate("DROVLGet") 
		//Salva Pagamento adicionado pelo PBM
		nPosPgtoPBM := aScan( aPgtos, {|x| x[3] == "CO" } )
			
		If nPosPgtoPBM > 0
			aPgtoPBM := aPgtos[nPosPgtoPBM]
			aDel(aPgtos,nPosPgtoPBM)
			aSize(aPgtos,Len(aPgtos)-1)
		EndIf	
	EndIf	
	
	aEval( aPgtos, { |x| nVlrAux += x[2] } )
	
	If Len(aPgtoPBM) > 0
		aAdd(aPgtos, aPgtoPBM)
	EndIf

	If nVlrDesc > 0
		If lExibeTela .AND. ValType(oPanVA3) == "O" .AND. oPanVA3:lVisibleControl .AND. nVlrAux > 0
			aDesconto[1] := 2	// Depois da condicao de pagamento
		Else
			aDesconto[1] := 1	// Antes da condicao de pagamento
		Endif

		aAcrescimo[1] := 0					// Valor do acrescimo
		aAcrescimo[2] := 0					// Percentual do acrescimo
		M->LQ_JUROS   := 0
	Else
		aDesconto[1] := 0		// Nao tem desconto
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Retorna o valor do preco unitario e do item, no aCols sem  ³
		//³o desconto global.										  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nRotina == 4 .AND. cPaisLoc <> "BRA"
			For nX:= 1 to Len(aCols)
				If !aCols[nX][Len(aCols[nX])]
					aCols[nX][nPosVrUnit] := Round( (aColsDet[nX][nPosPrcTab] - (aCols[nX][nPosValDesc] / aCols[nX][nPosQtda])), 2 )
					aCols[nX][nPosVlItem] := (aColsDet[nX][nPosPrcTab] * aCols[nX][nPosQtda]) - aCols[nX][nPosValDesc]
				EndIf
			Next nX
		EndIf
	Endif

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Faz um bkp do valor de desconto antigo que sera usado na    ³
	//³gravacao do SL2, caso seja uma gravacao de orcamento. nOpc=4³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    Lj7SetDescAnt( aDesconto[3] )
	aDesconto[2] := nPerDesc
	aDesconto[3] := nVlrDesc

	If cPaisLoc == "BRA"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta o valor Total da venda                                ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7T_Total( 2, LJ7T_Total(2) + Lj7T_DescV(2) )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta os valores de desconto (valor e percentual)           ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nVlrDesc <= 0 .And. nPercDesc > 0
			nPercDesc := 0 //Existem casos que o valor vem zerado o percentual vem maior porem isso causa problema nos calculos depois
		EndIf
		
	    Lj7T_DescV( 2, nVlrDesc )
	    LJ7T_DescP( 2, nPerDesc )
		
		/* Ajusta o valor Total da venda */		
		Lj7T_Total( 2, LJ7T_Total(2) - nVlrDesc )
	Else
		Lj7ZeraDesc( nRotina )
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta os valores de desconto (valor e percentual)           ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	    Lj7T_DescV( 2, nVlrDesc )
	    LJ7T_DescP( 2, nPerDesc )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Zera o total, pois dentro da funcao Lj7DescPro ira reconstruir³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7T_Total ( 2, 0 )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Proporcionaliza o desconto total nos produtos para que seja realizado³
		//³o recalculo dos impostos variaveis                                   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7DescPro(nVlrDesc, nVlrMerc)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Ajusta o valor do SubTotal.³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		Lj7T_SubTotal (2, Lj7T_Total(2))

	    For nX := 1 to Len(aPgtos)
	    	nVlrComp += aPgtos[nX][2] // quando volta para tela de itens e da desconto total na venda
	    Next nX
	    If Lj7T_Total(2) < nVlrComp .AND. Len(aPgtos) > 0
	    	Lj7ZeraPgtos()        // Zera forma de pagamento
	    EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta o array aPgtos, qdo necessario, e atualiza a exibicao das parcelas.   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nVlrAux > 0
		If !(cPaisloc $ "ARG/MEX")
			aRet := Lj7CalcPgt( Lj7T_Total(2), "CN", {1,aPgtos[1][1],0,0,Len(aPgtos),30,.T.},,,,,MAFisRet(, "NF_VALSOL") )
			For nX := 1 to Len(aRet)
				aPgtos[nX][2] := aRet[nX][2]
				If lVisuSint .AND. !Empty(aPgtosSint)
					If nX <= Len( aPgtosSint )
						aPgtosSint[nX][3] := TransForm(aRet[nX][2],PesqPict("SL4","L4_VALOR",,nMoedaCor))
					Endif
				EndIf
			Next nX
		EndIf

		If lVisuSint
			If ValType(oPgtosSint) == "O"
				oPgtosSint:Refresh()
			EndIf
		Else
			If ValType(oPgtos) == "O"
				oPgtos:Refresh()
			EndIf
		EndIf
	Endif
	
	If LjAnalisaLeg(22)[1] .AND. nVlrDesc > 0 .AND. !lIntegDef
		IfDescTot(nHdlECF, Str(nVlrDesc, 10, 2))
	EndIf

	//zera o valor da NCC que foi selecionada antes da chamada de recálculo, pois este valor era 
	//somado ao valor das parcelas dobrando o seu valor ao retornar a tela de pagamentos. 
	nNCCUsada := 0
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta o Valor das Parcelas e o Valor do Troco               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7AjustaTroco()

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se o desconto no total foi ajustado manualmente, nao havera    ³
	//³mais controle de desconto por regra nos totais para esta venda.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lExibeTela
		LjDescOff()
	EndIf
Endif

If Lj7Mv_Desc() .AND. lExibeTela
	If oMotivoDes == Nil
		oMotivoDes := LJCClaDes():New()
	EndIf

	If nVlrDesc > 0
		lRet := oMotivoDes:ChamaTela(99999)
	ElseIf nVlrDesc == 0
		oMotivoDes:RmValida(99999)
	EndIf
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7DetalheºAutor  ³ Vendas Clientes    º Data ³  11/09/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Grava as informacoes de detalhe do produto                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³ExpL1 - Determina se os impostos variaveis devem ser        º±±
±±º          ³recalculados                                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³void Lj7Detalhe()                                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7Detalhe(lCalcImpsV	, lAlterProd	, lValidCli		, cCpoOrigem	,; 
					lIsRecCP	, nVlrRecCP		, lReproVlIt	)

Local nPosItem		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})][2]			// Posicao do numero do item
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]		// Posicao da codigo do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]			// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]			// Posicao do Valor unitario do item
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]		// Posicao do Valor do item
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]		// Posicao do valor de desconto
Local nPosDtItem	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})					// Posicao do numero do item
Local nPosDtProd	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})					// Posicao do Codigo do produto
Local nPosDtTes		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})						// Posicao do Codigo do TES
Local nPosDtCF		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"})						// Posicao do Codigo do CF
Local nPosDtBIcm	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_BASEICM"})					// Posicao da Base de ICM
Local nPosDtVIcm	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALICM"})					// Posicao do Valor do ICM
Local nPosDtVIpi	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALIPI" })					// Posicao do Valor do IPI
Local nPosDtVIss 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALISS" })					// Posicao do Valor do ISS
Local nPosDtTabela	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TABELA" })					// Posicao da Tabela de precos
Local nPosDtDProp	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO" })				// Posicao do Desconto proporcional
Local nPosDtPrcTab  := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})					// Posicao do Preco de Tabela
Local nPosDtFrete	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALFRE" })					// Posicao do Valor do frete do item
Local nPosDtSeguro 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_SEGURO"})					// Posicao do Valor do Seguro do item
Local nPosDtDespesa	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESPESA"})					// Posicao do Valor das desepesas acessorias do item
Local nPosDtReserva	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_RESERVA"})					// Posicao do codigo da reserva
Local nPosDtLojaRes	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOJARES"})					// Posicao do Loja da reserva
Local nPosDtOrcRes 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_ORCRES" })					// Posicao do orcamento da reserva
Local nPosDtEmpRes 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_EMPRES" })					// Posicao do codigo da empresa da reserva
Local nPosDtFilRes 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_FILRES" })					// Posicao do codigo da filial da empresa da reserva
Local nPosDtLocal  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCAL" })					// Posicao do local (armazem)
Local nPosNSerie   	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NSERIE" })					// Posicao do Numero de serie
Local nPosLoteCTL  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL" })				// Posicao do Sub Lotermazem)
Local nPosNLote    	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE" })					// Posicao do Lote
Local nPosDtValid  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DTVALID"})					// Posicao da Data de validade do Lote
Local nPosLocaliz  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCALIZ"})					// Posicao do Localizacao
Local nPosValePre  	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_VALEPRE"})					// Posicao do Vale Presente
Local nPosTurno	 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TURNO"})					// Posicao do codigo da reserva
Local nPosCodLan 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CODLAN"})					// Posicao do codigo da reserva
Local nPosDescIcm 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCICM"})					//
Local nPosMotdIcm 	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_MOTDICM"})					//
Local nPos			:= 0							  												// Auxiliar para localizacao em arrays
Local cTesPad		:= ""																			// Codigo do Tes de saida
Local lLinOk        := .F.                 			   											   	// Identifica se a funcao foi chamada pela LINOK ou pela DELOK.
Local nMoedaPrv		:= 0																		   	// Moeda da tabela de preco selecionada
Local cTesSai		:= SuperGetMV("MV_TESSAI",,"501")											   	// Pega do parametro o TES padrao para saida
Local cTesInt		:= ""																			// Codigo do Tes de saida
Local nPrecoTab		:= 0																			// Varivel para armazenar o preco da tabela
Local cTurnoPad		:= SuperGetMv("MV_LJTURNO",,"M")												// Pega o turno padrao
Local cB1Tes		:= ""
Local aTmpColsD    	:= {} 						       											    // Possui aColsDet Zerado
Local aImps			:= {}
Local nX			:= 0
Local nSaldoSB8		:= 0
Local cTmpHas		:= ""
Local nPosHas		:= 0
Local cImps			:= ""
Local aAreaSB1		:= {}
Local lCalcIPI      :=  .T.
Local nPrcUnit 		:= 0
Local nValMerc		:= 0
Local lLj7Tabela	:= IsInCallStack("LJ7TABELA")
Local nQtde 		:= 0
/*Release 11.5 - Localizacoes
Chile,Colombia  - F1CHI	*/
Local lLocR5		:= cPaisLoc$"CHI|COL"
Local cMvDescSai	:= SuperGetMV("MV_DESCSAI",,"1")												// Desconto tratamento localizacoes
Local lCAT83		:= SF4->(ColumnPos("F4_CODLAN")) > 0 .AND. ExistFunc("FISA023") .AND. SuperGetMV("MV_CAT8309",,.F.) // Valida Cat83
Local nRecSF4		:= 0
Local nRecSB1		:= 0
Local lSFinanc    	:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)							// Valida implementação do servico financeiro
Local cMvLjTSF		:= SuperGetMV("MV_LJTPSF",,"SF")												// Tipo Servico Financeiro
Local lRecalcFis	:= .F.
Local cTpFrete 		:= ""
Local lIntSynt 	 	:= SuperGetMV("MV_LJSYNT",,"0") == "1"	 										// Informa se a integracao Synthesis esta ativa
Local nValIPI       := 0
Local nPosTesInt	:= 0
Local lIntegDef		:= If(Type("lAutoExec") == "L", lAutoExec, .F.) .And. FWHasEAI("LOJA701",, .T., .T.) .AND. IIF( ExistFunc("Lj701GtInD") , Lj701GtInD(), IsInCallStack("LOJI701"))  //Integracao via Mensagem Unica
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local cNomeProg		:= Iif(lFtvdVer12,"FATA701","LOJA701")	//Nome da Rotina

Default lCalcImpsV 	:= .T.																			// Determina se os impostos variaveis devem ser recalculados
Default lAlterProd 	:= .F.																			// Indica que eh alteracao do produto
Default lValidCli  	:= .F.
Default cCpoOrigem 	:= ""
Default lIsRecCP   	:= .F. 																			// Indica que eh produto de Recarga de Cartao Presente (Gift Card)
Default nVlrRecCP  	:= 0 																			// Valor da Recarga de Cartao Presente (Gift Card)
Default lReproVlIt 	:= .F.

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Tratamento da funcao que podera ser chamada pela LinOk() ³
//³A funcao &(Readvar()) nao pode ser executada n LinOk().  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ("LJ7LINOK" $ ProcName(1)) .OR. ("LJ7VALDEL" $ ProcName(1)) .OR. ("LINHAOK" $ ProcName(4))
	lLinOk	:= .T.
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Posiona os arquivos para a rotina                                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
SB1->(DbSetOrder( 1 ))
SB1->(DbSeek( xFilial("SB1") + aCols[n][nPosProd] ))

SB0->(DbSetOrder( 1 ))
SB0->(DbSeek( xFilial("SB0") + aCols[n][nPosProd] ))

//Tratamento ExecAuto: Se TES informada, considera TES recebida
If lAutoExec .AND. (Len(aColsDet) >= n) .AND. !Empty(aColsDet[n][nPosDtTes])
	cTesPad := aColsDet[n][nPosDtTes]
Else
	//---
	// PRIORIDADE: TES INTELIGENTE (SFM)
	// Parametro da funcao MaTESInt
	// ExpN1 = Documento de 1-Entrada / 2-Saida
	// ExpC1 = Tipo de Operacao Tabela "DF" do SX5
	// ExpC2 = Codigo do Cliente ou Fornecedor
	// ExpC3 = Codigo do gracao E-Entrada
	// ExpC4 = Tipo de Operacao E-Entrada
	//---
	
	//-----------------------------------------------------------------------------------------------
	// Tratamento para pegar as informações da Tes Inteligente no array estatico caso já tenha sido 
	// consultado na função MaTesInt anteriormente, para melhoria de performance no venda assistida.
	//-----------------------------------------------------------------------------------------------
	nPosTesInt := aScan(aTesInt, {|x| x[1] + x[2] + x[3] == M->LQ_CLIENTE + M->LQ_LOJA + aCols[n][nPosProd] } ) 
	If nPosTesInt > 0
		cTESInt := aTesInt[nPosTesInt][4]
	Else
		cTESInt := MaTesInt( 2	, "01"				, M->LQ_CLIENTE	, M->LQ_LOJA,;
							"C"	, aCols[n][nPosProd], NIL 			)
	
		aAdd(aTesInt, { M->LQ_CLIENTE, M->LQ_LOJA, aCols[n][nPosProd], cTESInt } )
	EndIf
	
	If !Empty(cTesInt)
		cTesPad := cTesInt
	Else
		//obtemos o TES padrao
		cTesPad := IIf( Empty( RetFldProd(SB1->B1_COD,"B1_TS") ), cTesSai, RetFldProd(SB1->B1_COD,"B1_TS") )

		//caso seja Servicos Financeiros, subtituimos o TES padrao
	 	If lSFinanc .AND. SB1->B1_TIPO == cMvLjTSF
			MG8->( dbSetOrder(2) )
			If MG8->( DbSeek(xFilial("MG8") + aCols[n][nPosProd]) )
				cTesPad := MG8->MG8_TESSB1
			EndIf
		EndIf
	EndIf
EndIf

SF4->( DbSeek(xFilial("SF4") + cTesPad) )
SA1->( DbSetOrder(1) )
SA1->( DbSeek(xFilial("SA1") + M->LQ_CLIENTE + M->LQ_LOJA) )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se o produto ja esta no array de detalhes                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nPos := If( n>Len(aColsDet), nPos:=0, nPos:=n )
If nPos == 0
	If !(MafisFound())
		If lIntegDef
			lCalcIPI := .F.
		Else
			lCalcIPI := Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_VALIPI"})	 > 0
		EndIf

		cTpFrete := Lj7TpFrete(Nil,Nil)
		cTpFrete	:= IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)		
		MaFisIni( M->LQ_CLIENTE, M->LQ_LOJA, "C" , "S" , ;
		          NIL          , NIL        , NIL , .F., ;
		          "SB1"        , cNomeProg  , NIL , NIL, ;
		          NIL          , NIL        , NIL , NIL, ;
		          NIL          , NIL        , NIL , lCalcIPI,;
		          NIL          , NIL        , NIL , NIL, ;
		          NIL          , cTpFrete )
		LjSatMxFis()
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³SigaPhoto - Inicializa campos do aColsDet.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nModulo == 72
		// Carrega aColsDet vazio.
		aTmpColsD := KDaColsDet()

		AAdd( aColsDet, aTmpColsD[1] )
	Else
		aAdd( aColsDet, Array( Len(aHeaderDet)+1 ) )
	EndIf

	nPos	:= Len( aColsDet )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Quando for inclusao de um novo item chama a funcao MafisAdd              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lFtvdVer12
		MaFisAdd( aCols[n][nPosProd],;			// Produto
					cTesPad,;					// Tes
					aCols[n][nPosQuant],;		// Quantidade
					aCols[n][nPosVlUnit],;		// Preco unitario
					aCols[n][nPosValDesc],;		// Valor do desconto
					"",; 						// Numero da NF original
					"",; 						// Serie da NF original
					0,;							// Recno da NF original
					0,; 						// Valor do frete do item
					0,; 						// Valor da despesa do item
					0,; 						// Valor do seguro do item
					0,; 						// Valor do frete autonomo
					aCols[n][nPosVlItem] + IIf(cPaisLoc == "BRA", aCols[n][nPosValDesc], 0),;		// Valor da mercadoria
					0 )							// Valor da embalagem

	ElseIf lFtvdVer12	.And. !Empty(aCols[n][nPosProd])
		MaFisIniLoad(	n							,;	//Numero do Item no Acols
						{aCols[n][nPosProd]			,;	//IT_PRODUTO
						cTesPad						,; 	//IT_TES
						SB1->B1_CODISS				,; 	//IT_CODISS
						aCols[n][nPosQuant]			,;	//IT_QUANT
						""							,; 	//IT_NFORI
						""							,; 	//IT_SERIORI
						SB1->(RecNo())				,;	//IT_RECNOSB1
						SF4->(RecNo())				,;	//IT_RECNOSF4
						0  							}) 	//IT_RECORI

		MaFisLoad("IT_VALMERC"	,aCols[n][nPosVlItem] + IIf(cPaisLoc == "BRA", aCols[n][nPosValDesc], 0)	, n)
		MaFisLoad("IT_PRCUNI"	,aCols[n][nPosVlUnit] , n)
		MaFisLoad("IT_DESCONTO"	,aCols[n][nPosValDesc], n)
		MaFisLoad("IT_FRETE"	,0	,n)
		MaFisLoad("IT_SEGURO"	,0	,n)
		MaFisLoad("IT_DESPESA"	,0	,n)

		MaFisRecal("",n)
		MaFisEndLoad(n,2)
	EndIf

	If cPaisLoc <> "BRA" .And. Len(aCols) > 1
		Lj7AtuDesc()
	EndIf

Else

	If lFtvdVer12
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Chama a funcao MaFisAlt somente quando for alteracao de algum produto.   ³
		//³ Cuidado com a alteracao destas linhas pois afeta diretamente quando eh   ³
		//³ utilizado descontos no item e total dos produtos                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		cTesPad := IIf("LR_PRODUTO" $ ReadVar() .OR. "LQ_CLIENTE" $ ReadVar(),cTesPad,aColsDet[nPos][nPosDtTes])

		SF4->(DbSeek(xFilial("SF4")+cTesPad))

   		nRecSF4	:= SF4->( RecNo() )
   		nRecSB1 := SB1->( Recno() )

		If n == 1 .And. !Empty(aCols[n][nPosProd])
			MaFisIniLoad(	n							,;	//Numero do Item no Acols
							{aCols[n][nPosProd]			,;	//IT_PRODUTO
							cTesPad						,; 	//IT_TES
							SB1->B1_CODISS				,; 	//IT_CODISS
							aCols[n][nPosQuant]			,;	//IT_QUANT
							""							,; 	//IT_NFORI
							""							,; 	//IT_SERIORI
							nRecSB1						,;	//IT_RECNOSB1
							nRecSF4						,;	//IT_RECNOSF4
							0  							}) 	//IT_RECORI
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Chama a funcao MaFisAlt somente quando for alteracao de algum produto.   ³
	//³ Cuidado com a alteracao destas linhas pois afeta diretamente quando eh   ³
	//³ utilizado descontos no item e total dos produtos                         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
 	If MaFisFound("IT",n) .AND. ( lCalcImpsV .OR. cPaisLoc == "BRA" )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³A funcao Lj7TotImpsV() eh chamada nesse ponto para que o os impostos do produto anterior ³
		//³sejam subtraidos do array com o total dos impostos variaveis...                          ³
		//³A funcao IsInCallStack verifica se a rotina Lj7Detalhe foi acionada a partir da troca de ³
		//³tabela de precos (Lj7Tabela)                                                             ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cPaisLoc <> "BRA" .AND.;
			( (ReadVar() $ "M->LR_PRODUTO|M->LR_QUANT|M->LR_VRUNIT|M->LR_VLRITEM|M->LR_DESC|M->LR_VALDESC" .AND. Lj7T_DescV(2) == 0) .OR.;
			lLj7Tabela )
		   	Lj7TotImpsV(n,4)
		EndIf

		If cPaisLoc <> "BRA"

	 		If "LR_PRODUTO" $ ReadVar()
		 		lAlterProd	:= .T.
	 			//Seta a variavel lRecalcFis para indicar que deve executar o recalculo de tods os itens da MatxFis devido ter alterado o produto, pois os valores nao eram recalculados corretamente dentro da MatxFis
		 		lRecalcFis := If(!lLinOk, &(ReadVar()) <> MaFisRet(n, "IT_PRODUTO"), .F.)
				If !lFtvdVer12
					MaFisLoad("IT_PRODUTO"	,If("LR_PRODUTO"$ReadVar()	,If(!lLinOk,&(ReadVar()),aCols[n][nPosProd])	,aCols[n][nPosProd])	,n)
				ElseIf lFtvdVer12
					MaFisLoad("IT_PRODUTO"	,If("LR_PRODUTO"$ReadVar(), if(!lLinOk,IIf(!lValidCli,&(ReadVar()),aCols[n][nPosProd]),aCols[n][nPosProd])	,aCols[n][nPosProd])	,n)
				EndIf
			ElseIf "LR_QUANT" $ ReadVar()
		 		lAlterProd	:= .T.
		 		nQtde := If(!lReproVlIt .And. "LR_QUANT"	$ReadVar()	,If(!lLinOk,&(ReadVar()),aCols[n][nPosQuant])	,aCols[n][nPosQuant])
				MaFisLoad("IT_QUANT", nQtde ,n)
				If Len(aCols) > 1
					Lj7AtuDesc()
				EndIf
			ElseIf "LR_VRUNIT" $ ReadVar()
				MaFisLoad("IT_PRCUNI"	,If("LR_VRUNIT"	$ReadVar()	,If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]),aCols[n][nPosVlUnit])	,n)
			ElseIF "LR_VALDESC" $ ReadVar()
				aCols[n][nPosValDesc] := If(!lLinOk,&(ReadVar()),aCols[n][nPosValDesc])
				Lj7AtuDesc()
			ElseIF "LR_DESC" $ ReadVar()
				Lj7AtuDesc()
			Endif
			If lLj7Tabela .OR. (!Empty(ReadVar()) .And. !(ReadVar() $ "M->LR_VALDESC|M->LR_DESC"))
				MaFisLoad("IT_DESCONTO", aCols[n][nPosValDesc], n)
			Endif

			MaFisLoad("IT_TES",If("LR_PRODUTO"$ReadVar(),cTesPad,aColsDet[nPos][nPosDtTes]),n)

			If lFtvdVer12
				MaFisLoad("IT_RECNOSF4",nRecSF4,n)
			EndIf

			MaFisLoad("IT_ALIQIPI",SB1->B1_IPI,n)
			
			If "LR_VLRITEM"$ReadVar() .And. !lLinOk
				nPrcUnit := &(ReadVar())
				nValMerc := &(ReadVar())
			Else
				// usar nPosVlUnit para nPrcUnit e IT_PRCUNI!!
				nPrcUnit := aCols[n][nPosVlUnit]
				nValMerc := aCols[n][nPosVlItem]
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Release 11.5 - Localizacoes                                          ³
			//³Se o parametro MV_DESCSAI estiver igual a 2, definir IT_VALMERC e    ³
			//³IT_PRCUNI com os descontos para os calculos da MATXFIS  				³
			//³Paises:CHILE, COLOMBIA  - F1CHI                                      ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	   		If lLocR5
	   			If cMvDescSai == "2"
					MaFisLoad("IT_PRCUNI",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]),aCols[n][nPosVlUnit]),n)
					MaFisLoad("IT_VALMERC",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlItem]),aCols[n][nPosVlItem]),n)
				Else
					MaFisLoad("IT_PRCUNI",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),n)
					MaFisLoad("IT_VALMERC",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),n)
				Endif

				If aCols[n][nPosValDesc] > 0
					Lj7DescPro(0, MaFisRet(nPos,"IT_VALMERC") )
				EndIf
			Else
				If "LR_QUANT" $ ReadVar()
					MaFisLoad("IT_PRCUNI",	nPrcUnit+aCols[n][nPosValDesc] ,n)
					MaFisLoad("IT_VALMERC",	nValMerc+aCols[n][nPosValDesc] ,n)
					MaFisLoad("IT_TES",	 	If("LR_PRODUTO"$ReadVar(),cTesPad,aColsDet[nPos][nPosDtTes]),n)
				Else
					MaFisLoad("IT_PRCUNI",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),n)
					MaFisLoad("IT_VALMERC",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),n)
				EndIf
			EndIf

			If lFtvdVer12
				MaFisLoad("IT_DESCONTO"	,aCols[n][nPosValDesc], n)
				MaFisLoad("IT_FRETE"	,0	,n)
				MaFisLoad("IT_SEGURO"	,0	,n)
				MaFisLoad("IT_DESPESA"	,0	,n)
			EndIf

			If !IsInCallStack("Lj7ValDel")
				MaFisRecal("",n)  //Recalcula impostos do Item
			  	StaticCall( MATXFIS, MaIt2cab )
				If lRecalcFis
					MaFisReprocess(2)
				EndIf
			EndIf

		Else			
			/* Necessário reposicionar: 
			- TES e Produto antes para que seja efetuado os calculos corretos de tributação
			- Zera a ref IT_VALMERC para apagar qualquer tipo de residuo do item anterior*/
			If lFtvdVer12
				MaFisAlt("IT_RECNOSF4",nRecSF4,n)
				MaFisAlt("IT_RECNOSB1",nRecSB1,n)
				MaFisAlt("IT_VALMERC", 0 , n )
			EndIf
			
			MaFisAlt("IT_TES",If("LR_PRODUTO"$ReadVar(),cTesPad,aColsDet[nPos][nPosDtTes]),n)
			
	 		If "LR_PRODUTO" $ ReadVar()
		 		lAlterProd	:= .T.
				If !lFtvdVer12
					MaFisAlt("IT_PRODUTO"	,If("LR_PRODUTO"$ReadVar()	,If(!lLinOk,&(ReadVar()),aCols[n][nPosProd])	,aCols[n][nPosProd])	,n)
				ElseIf lFtvdVer12
					MaFisAlt("IT_PRODUTO"	,If("LR_PRODUTO"$ReadVar()	,If(!lLinOk,IIf(!lValidCli,&(ReadVar()),aCols[n][nPosProd]),aCols[n][nPosProd]),aCols[n][nPosProd]),n)
				EndIf
			ElseIf "LR_QUANT" $ ReadVar()
		 		lAlterProd	:= .T.
				MaFisAlt("IT_QUANT"		,If("LR_QUANT"	$ReadVar()	,If(!lLinOk,&(ReadVar()),aCols[n][nPosQuant]),aCols[n][nPosQuant])	,n)
			ElseIf "LR_VRUNIT" $ ReadVar()
				MaFisAlt("IT_PRCUNI"	,If("LR_VRUNIT"	$ReadVar()	,If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]),aCols[n][nPosVlUnit]),n)
			ElseIF "LR_VALDESC" $ ReadVar()
				aCols[n][nPosValDesc] := If(!lLinOk,&(ReadVar()),aCols[n][nPosValDesc])
				MaFisAlt("IT_DESCONTO"	, aCols[n][nPosValDesc], n)
			ElseIF "LR_DESC" $ ReadVar()
				MaFisAlt("IT_DESCONTO"	, aCols[n][nPosValDesc], n)
			Endif
			
			If lLj7Tabela .OR. (!Empty(ReadVar()) .And. !(ReadVar() $ "M->LR_VALDESC|M->LR_DESC"))
				MaFisAlt("IT_DESCONTO", aCols[n][nPosValDesc], n)
			Endif			

			// Caso possuir Execao Fiscal peço para a Matxfis Recalcular o valor do IPI
			If !Empty(SB1->B1_GRTRIB)
				MaFisRecal("IT_ALIQIPI",n) 
			Else 
				MaFisAlt("IT_ALIQIPI",SB1->B1_IPI,n)
			EndIf

			If "LR_VLRITEM"$ReadVar() .And. !lLinOk
				nPrcUnit := &(ReadVar())
				nValMerc := &(ReadVar())
			Else
				// usar nPosVlUnit para nPrcUnit e IT_PRCUNI!!
				If cPaisLoc == "ARG"
					nPrcUnit := aCols[n][nPosVlUnit]
					nValMerc := aCols[n][nPosVlItem]
				Elseif cPaisLoc == "MEX"
					nPrcUnit := aCols[n][nPosVlUnit]
					nValMerc := aCols[n][nPosVlItem]+aCols[n][nPosValDesc]
				Else
					nPrcUnit := aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]
					nValMerc := aCols[n][nPosVlItem]+aCols[n][nPosValDesc]
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Release 11.5 - Localizacoes                                          ³
			//³Se o parametro MV_DESCSAI estiver igual a 2, definir IT_VALMERC e    ³
			//³IT_PRCUNI com os descontos para os calculos da MATXFIS  				³
			//³Paises:CHILE, COLOMBIA  - F1CHI                                      ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	   		If lLocR5
	   			If cMvDescSai == "2"
					MaFisAlt("IT_PRCUNI",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]),aCols[n][nPosVlUnit]),n)
					MaFisAlt("IT_VALMERC",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlItem]),aCols[n][nPosVlItem]),n)
				Else
					MaFisAlt("IT_PRCUNI",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),n)
					MaFisAlt("IT_VALMERC",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),n)
				Endif

				If aCols[n][nPosValDesc] > 0
					Lj7DescPro(0, MaFisRet(nPos,"IT_VALMERC") )
				EndIf
			Else
				If cPaisLoc <> "ARG" .Or. ("LR_QUANT" $ ReadVar())
					MaFisAlt("IT_PRCUNI",	nPrcUnit,n)
					MaFisAlt("IT_VALMERC",	nValMerc,n)
				Else
					MaFisAlt("IT_PRCUNI",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),aCols[n][nPosVlUnit]+aCols[n][nPosValDesc]),n)
					MaFisAlt("IT_VALMERC",	If("LR_VLRITEM"$ReadVar(),If(!lLinOk,&(ReadVar()),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),aCols[n][nPosVlItem]+aCols[n][nPosValDesc]),n)
				EndIf
			EndIf

			If lFtvdVer12
				MaFisLoad("IT_DESCONTO"	,aCols[n][nPosValDesc], n)
				MaFisLoad("IT_FRETE"	,0	,n)
				MaFisLoad("IT_SEGURO"	,0	,n)
				MaFisLoad("IT_DESPESA"	,0	,n)
				
				MaFisRecal("",n)
			EndIf

		EndIf

	ElseIf !MaFisFound("IT",n) .AND. lAutoExec
		If !(MafisFound())
            If lIntegDef
                lCalcIPI := .F.
            EndIf

			cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)
			cTpFrete	:= IIf( Empty(cTpFrete) .And. (M->LQ_TPFRET == "S" .OR. M->LQ_TPFRET == "0"), "S", cTpFrete)
			MaFisIni( M->LQ_CLIENTE, M->LQ_LOJA, "C" , "S" , ;
			          M->LQ_TIPOCLI , NIL        , NIL , .F., ;
			          "SB1"        , "LOJA701"  , NIL , NIL, ;
			          NIL          , NIL        , NIL , NIL, ;
			          NIL          , NIL        , NIL , lCalcIPI,;
			          NIL          , NIL        , NIL , NIL, ;
			          NIL          , cTpFrete)
			LjSatMxFis()
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Quando for inclusao de um novo item chama a funcao MafisAdd              ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		MaFisAdd( aCols[n][nPosProd],;			// Produto
					cTesPad,;					// Tes
					aCols[n][nPosQuant],;		// Quantidade
					aCols[n][nPosVlUnit],;		// Preco unitario
					aCols[n][nPosValDesc],;		// Valor do desconto
					"",; 						// Numero da NF original
					"",; 						// Serie da NF original
					0,;							// Recno da NF original
					0,; 						// Valor do frete do item
					0,; 						// Valor da despesa do item
					0,; 						// Valor do seguro do item
					0,; 						// Valor do frete autonomo
					aCols[n][nPosVlItem] + IIf(cPaisLoc == "BRA", aCols[n][nPosValDesc], 0),;		// Valor da mercadoria
					0 )							// Valor da embalagem
	Endif
Endif

aColsDet[nPos][nPosDtItem] 	    := aCols[n][nPosItem]
aColsDet[nPos][nPosDtProd] 	    := aCols[n][nPosProd]
aColsDet[nPos][nPosDtTes]	 	:= If(Empty(aColsDet[nPos][nPosDtTes]),cTesPad,IIf("LR_PRODUTO" $ ReadVar(),cTesPad,aColsDet[nPos][nPosDtTes]))

//Integracao mantem CFOP informado na integracao
If !lIntegDef
	aColsDet[nPos][nPosDtCF]	:= If(MaFisFound("IT",n),MaFisRet(n,"IT_CF"),aColsDet[nPos][nPosDtCF])
EndIf

If cPaisLoc == "BRA"
   //Integracao mantem informacoes de CFOP e impostos integrados
	If !lIntegDef
	   If aColsDet[nPos][nPosDtCF] != NIL
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Atualiza CFO de devido a nao correspondencia do CFO estadual  ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If Left(aColsDet[nPos][nPosDtCF],4) == "6405"
				aColsDet[nPos][nPosDtCF] := "6404"+SubStr(aColsDet[nPos][nPosDtCF],5,Len(aColsDet[nPos][nPosDtCF])-4)
	   		EndIf
	   EndIf
	
	   If MaFisFound("IT",n)
			If MaFisRet(n,"IT_VALICM") > 0
				aColsDet[nPos][nPosDtBIcm]	:= MaFisRet(n,"IT_BASEICM")
				aColsDet[nPos][nPosDtVIcm]	:= MaFisRet(n,"IT_VALICM")
	
				If MaFisRet(n,"IT_DEDICM") > 0 .And. nPosDescIcm > 0 .And. nPosMotdIcm > 0
					aColsDet[nPos][nPosDescIcm]	:= MaFisRet(n,"IT_DEDICM")
					aColsDet[nPos][nPosMotdIcm]	:= MaFisRet(n,"LF_MOTICMS")
				EndIf
			Endif
			If MaFisRet(n,"IT_VALISS") > 0
				aColsDet[nPos][nPosDtVIss] := MaFisRet(n,"IT_VALISS")
			EndIf
	
	   		If nPosDtVipi > 0
		   		nValIPI := MaFisRet(n,"IT_VALIPI")
				aColsDet[nPos][nPosDtVIpi]	:= nValIPI
	   		EndIf		
	   Else
	   		If nPosDtVipi > 0
	   			aColsDet[nPos][nPosDtVIpi]	:= NIL
	   		EndIf
	   Endif
	EndIf

ElseIf cPaisLoc <> "BRA" .AND. lFtvdVer12
	aColsDet[nPos][nPosDtCF]	:= If(MaFisFound("IT",n),MaFisRet(n,"IT_CF"),aColsDet[nPos][nPosDtCF])
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Faz a busca do Armazem somente quando se digita o codigo³
//³do produto e para PBM Funcional Card sem template.       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//Caso a chamada seja pelo valid do cliente não atualizo o armazem.
If !lValidCli .AND. ( "M->LR_PRODUTO" $ Readvar()) .OR. (Type("M->LQ_PRODUTO") == "C" .AND. ( "M->LQ_PRODUTO" $ Readvar()))  .Or. ExistTemplate("DROVLGet") 
	If !(lAutoExec .AND. !Empty(aColsDet[nPos][nPosDtLocal]) ) 	// Respeita o enviado pela ExecAuto
		aColsDet[nPos][nPosDtLocal] := Iif(Empty(SB1->B1_COD),aColsDet[nPos][nPosDtLocal],RetFldProd( SB1->B1_COD,"B1_LOCPAD"))
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Para localizacoes, somente zera o desconto quando for alteracao³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lIntegDef //Integracao nao zera desconto proporcional, deve manter o valor integrado
	If cPaisLoc == "BRA" .OR. lCalcImpsV
		aColsDet[nPos][nPosDtDProp]	 := 0 // Implementar o desconto proporcional
	EndIf
EndIf

If lCenVenda
	aColsDet[nPos][nPosDtTabela]  := LjXETabPre(M->LQ_CLIENTE,M->LQ_LOJA)
	cTabPreco := aColsDet[nPos][nPosDtTabela]
ElseIf lLj7Tabela .OR. Empty(aColsDet[nPos][nPosDtTabela])
	aColsDet[nPos][nPosDtTabela]  := cTabPad
	cTabPreco := cTabPad
Else
	cTabPreco := aColsDet[nPos][nPosDtTabela]
EndIf

If nPosValePre > 0
	aColsDet[nPos][nPosValePre]	:= If( Empty(aColsDet[nPos][nPosValePre]),Space(TamSx3("L2_VALEPRE")[1]),aColsDet[nPos][nPosValePre])
EndIf

If !Empty(aColsDet[nPos][nPosValePre]) //Se for Vale Presente, atribuo novamente o preço do vale presente escolhido para o Preço de Tabela, pois o valor do vale presente é cadastrado em MDD_VALOR.
	//Vide a linha aprox. 1440: a variável nPosDtMont tem o mesmo que nPosDtPrcTab, por isso é passado por aqui novamente. 
	aColsDet[nPos][nPosDtPrcTab]	:= aColsDet[nPos][nPosVlUnit]
ElseIf lIsRecCP //Recarga de Cartao Presente (Gift Card)
	If aColsDet[nPos][nPosDtPrcTab] == NIL .OR. lAlterProd
		aColsDet[nPos][nPosDtPrcTab] := nVlrRecCP //Considera como preco, o valor informado no TEF no momento da Recarga do Cartao Presente (Gift Card)
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³SIGAPHOTO - O preco de venda sempre retorna da funcao LjxeValPre, porque dentro dela ja a a validacao para Cenario de Vendas.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
ElseIf nModulo == 72
	LjxeValPre (@nPrecoTab	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
				nMoedaCor	, If("LR_QUANT"$ReadVar(),&(ReadVar()),aCols[n][nPosQuant]) )
	aColsDet[nPos][nPosDtPrcTab]	:= nPrecoTab
ElseIf !lIntSynt .AND. !(lAutoExec .AND. !Empty(aColsDet[nPos][nPosDtPrcTab]) )
	If lCenVenda
		If ( (!Empty(aCols[n][nPosProd]) .AND. lFTVDVer12) .OR. !lFTVDVer12 ) .AND. ( !IsInCallStack("Lj7LinOk") )
			LjxeValPre (@nPrecoTab	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
						nMoedaCor	, If("LR_QUANT"$ReadVar(),&(ReadVar()),aCols[n][nPosQuant]) )
			aColsDet[nPos][nPosDtPrcTab]	:= nPrecoTab
		EndIf
	Else
	    If SB0->(ColumnPos("B0_PRV"+cTabPreco)) > 0
			If SB0->(ColumnPos("B0_MOEDA" + cTabPreco)) > 0
				nMoedaPrv := Max(&("SB0->B0_MOEDA" + cTabPreco),1)
				aColsDet[nPos][nPosDtPrcTab]	:= IIf( (cPaisLoc == "ARG" .AND. SB0->&("B0_PRV"+cTabPreco) == 0),aColsDet[nPos][nPosDtPrcTab],;
														A410Arred(xMoeda(&("SB0->B0_PRV" + cTabPreco),nMoedaPrv,nMoedaCor,dDataBase,nDecimais+1,,nTxMoeda),"L2_PRCTAB",nMoedaCor) )
			Else
				//Quando utiliza ExecAuto para gravacao da Venda, considera valor recebido
				If aColsDet[nPos][nPosDtPrcTab] == NIL .OR. (lAlterProd .AND. !lValidCli .AND. !lAutoExec)
					If (cPaisLoc == "ARG" .AND. SB0->&("B0_PRV"+cTabPreco) == 0)
						aColsDet[nPos][nPosDtPrcTab]	:= aColsDet[nPos][nPosDtPrcTab]
					ElseIf  !Empty(aCols[n][nPosProd])
						LjxeValPre (@nPrecoTab	, aCols[n][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA	,;
									nMoedaCor	, aCols[n][nPosQuant] )
						aColsDet[nPos][nPosDtPrcTab]	:= nPrecoTab
					Endif

				EndIf
			EndIf
		Endif
	Endif
EndIf

If aColsDet[nPos][Len(aColsDet[nPos])] == NIL
   aColsDet[nPos][Len(aColsDet[nPos])] := .F.
EndIf

If !lIntegDef
	aColsDet[nPos][nPosDtFrete]	    := If(MaFisFound("IT",n),MaFisRet(n,"IT_FRETE"),Nil)
	aColsDet[nPos][nPosDtSeguro]	:= If(MaFisFound("IT",n),MaFisRet(n,"IT_SEGURO"),Nil)
	aColsDet[nPos][nPosDtDespesa]	:= If(MaFisFound("IT",n),MaFisRet(n,"IT_DESPESA"),Nil)
Endif
aColsDet[nPos][nPosDtReserva]	:= If(Empty(aColsDet[nPos][nPosDtReserva]),Space(TamSx3("L2_RESERVA")[1]),aColsDet[nPos][nPosDtReserva])
aColsDet[nPos][nPosDtLojaRes]	:= If(Empty(aColsDet[nPos][nPosDtLojaRes]),Space(TamSx3("L2_LOJARES")[1]),aColsDet[nPos][nPosDtLojaRes])
aColsDet[nPos][nPosDtOrcRes]	:= If(Empty(aColsDet[nPos][nPosDtOrcRes]),Space(TamSx3("L2_ORCRES")[1]),aColsDet[nPos][nPosDtOrcRes])
aColsDet[nPos][nPosDtFilRes]	:= If(Empty(aColsDet[nPos][nPosDtFilRes]),Space(TamSx3("L2_FILRES")[1]),aColsDet[nPos][nPosDtFilRes])
aColsDet[nPos][nPosDtEmpRes]	:= If(Empty(aColsDet[nPos][nPosDtEmpRes]),Space(TamSx3("L2_EMPRES")[1]),aColsDet[nPos][nPosDtEmpRes])

//Campos da aColsDet que sao alterados durante o processamento
aColsDet[nPos][nPosNSerie]		:= If( Empty(aColsDet[nPos][nPosNSerie]),Space(TamSx3("L2_NSERIE")[1]),aColsDet[nPos][nPosNSerie])
aColsDet[nPos][nPosLoteCTL]	    := If( Empty(aColsDet[nPos][nPosLoteCTL]),Space(TamSx3("L2_LOTECTL")[1]),aColsDet[nPos][nPosLoteCTL])
aColsDet[nPos][nPosNLote]		:= If( Empty(aColsDet[nPos][nPosNLote]),Space(TamSx3("L2_NLOTE")[1]),aColsDet[nPos][nPosNLote])
aColsDet[nPos][nPosDtValid]		:= If( Empty(aColsDet[nPos][nPosDtValid]),CToD('  /  /  '),aColsDet[nPos][nPosDtValid])
aColsDet[nPos][nPosLocaliz]	    := If( Empty(aColsDet[nPos][nPosLocaliz]),Space(TamSx3("L2_LOCALIZ")[1]),aColsDet[nPos][nPosLocaliz])

If nPosTurno > 0 .AND. LJAnalisaLeg(47)[1]
	If Empty(aColsDet[nPos][nPosTurno])
		M->LR_TURNO 				:= cTurnoPad
		aColsDet[nPos][nPosTurno] 	:= cTurnoPad
	EndIf
EndIf
If lCAT83 .AND. nPosCodLan > 0
	aColsDet[nPos][nPosCodLan] 	:= SF4->F4_CODLAN
EndIf

If cPaisLoc == "ARG" .AND. ReadVar() $ "M->LR_PRODUTO|M->LR_QUANT|M->LR_TES"
	If nPosProd > 0 .AND. nPosLoteCTL > 0 .AND. nPosNLote > 0 .AND. Len(aColsDet) >= n .AND.;
			Len(aColsDet[n]) > nPosLoteCTL .AND. Len(aColsDet[n]) > nPosNLote

		aAreaSB1 := SB1->( GetArea() )
		If  Empty(aColsDet[n][nPosLoteCTL]) .AND. Empty(aColsDet[n][nPosNLote])
			SB1->( DbSetOrder(1) )
			If SB1->( DbSeek(xFilial("SB1") + aCols[n][nPosProd]) )
				cB1Tes	:= RetFldProd( SB1->B1_COD, "B1_TS" )
				If Empty( cB1Tes )
					cB1Tes := cTesSai
				EndIf
				If SB1->B1_RASTRO $ "LS"
					cTmpHas := AllTrim(SuperGetMv("MV_IMPSIVA",,"IVA|"))
					nPosHas := AT("|",cTmpHas)
					If nPosHas == 0
						nPosHas := Len(cTmpHas)
					EndIf
					cImps := IIf(Empty(Substr(cTmpHas,nPosHas+1)), "III|IIN", Substr(cTmpHas,nPosHas+1))
					aImps := TesImpInf(cB1Tes)
					For nX := 1 to Len(aImps)
						If aImps[nX][1] $ cImps
							nPosLote        := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE"})
							nPosLotCtl      := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL"})
							nPosDValid      := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DTVALID"})
							nPosPotenc      := 0
							F4Lote( NIL			, NIL						, NIL		, "701A"	,;
									SB1->B1_COD	, aColsDet[n][nPosDtLocal]	, NIL		, NIL		,;
									NIL			, NIL						, .T.		)
							MaFisAlt("IT_QUANT",aCols[n][nPosQuant]+1,n)
							MaFisAlt("IT_QUANT",aCols[n][nPosQuant],n)
							Exit
						EndIf
					Next nX
				EndIf
			EndIf
		EndIf
		RestArea(aAreaSB1)
	EndIf
EndIf

// Valoriza os campos de impostos no aColsDet e atualiza interface com o usuario...
If lCalcImpsV .AND. cPaisLoc <> "BRA" .AND. !aTail(aCols[nPos])
	Lj7RecalImp(nPos,3)
EndIf

Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjFrete   ºAutor  ³ Vendas Clientes     º Data ³  16/09/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Solicita ao usuario as informacoes do frete.                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1: Opcao para utilizacao na tela                        º±±
±±º          ³ ExpC1: Guarda o ultimo tipo de frete usado                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                             º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Frete( nOpc, nVlrAcrsFi  )
Local nX			:= 0								// Contador
Local nItem         := 0								// Quantidade de campos auxiliares utilizados
Local aCampos	 	:= {}								// Array com os campos para o Msmget
Local aFolders		:= { STR0020, STR0021, STR0022 }	// "Transporte"###"Dados Complementares"###"Valores"
Local aDadosFrete	:= {}								// Array com os dados do frete
Local aCpoDefault	:= {}								// Array com os campos padrões tratados
Local aCpoUser		:= {}								// Array com os campos de usuário que serão tratados
Local lContinua		:= .F.								// Variável para controlar se o usuário clicou em OK
Local lAltDados 	:= .T.								// Variavel para o controle da alteracao da enchoice com os dados do frete
Local aButtons      := {}								// Array com os botões exibidos na EnchoiceBar
Local oDlgFrete		:= Nil								// Objeto DIALOG usado na tela do frete
Local oEncFrete 	:= Nil								// Objeto ENCHOICE usado na tela do frete
Local nFrete		:= M->LQ_FRETE						// Valor M->LQ_FRETE para verificar se o valor foi alterado
Local nDespesa		:= M->LQ_DESPESA					// Valor M->LQ_DESPESA para verificar se o valor foi alterado
Local nSeguro		:= M->LQ_SEGURO						// Valor M->LQ_SEGURO para verificar se o valor foi alterado
Local aCamposAlt	:= {}								// Campos que permitem edicao (via X3_WHEN nao eh possivel)
Local lLj7086		:= ExistBlock("LJ7086")				// Indica se o ponto de entrada está compilado
Local aLj7086		:= {}								// Retorno do ponto de entrada LJ7086
Local aAuxDadFrt	:= {}
Local nPosTransp 	:= 0
Local nPosVeicul 	:= 0
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Estrutura da array aCamposAux                                ³
//³ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ³
//³ [01] - Nome do campo                                         ³
//³ [02] - Folder                                                ³
//³ [03] - Combo box                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama a funcao MaFisAlt quando for alteracao de algum produto³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Local aCamposAux	:= { { 	"LQ_TRANSP"		, 1, NIL, 1 }	,;
						  { "LQ_ENDCOB"		, 1, NIL, 2 }	,;
						  { "LQ_BAIRROC"	, 1, NIL, 3 }	,;
						  { "LQ_MUNC"		, 1, NIL, 4 }	,;
						  { "LQ_CEPC"		, 1, NIL, 5 }	,;
						  { "LQ_ESTC"		, 1, NIL, 6 }	,;
						  { "LQ_ENDENT"		, 1, NIL, 7 }	,;
						  { "LQ_BAIRROE"	, 1, NIL, 8 }	,;
						  { "LQ_MUNE"		, 1, NIL, 9 }	,;
						  { "LQ_CEPE"		, 1, NIL, 10 }	,;
						  { "LQ_ESTE"		, 1, NIL, 11 }	,;
						  { "LQ_VEICUL1"	, 2, NIL, 12 } ,;
						  { "LQ_VOLUME"		, 2, NIL, 13 }	,;
						  { "LQ_ESPECI1"	, 2, NIL, 14 }	,;
						  { "LQ_MARCA" 		, 2, NIL, 15 }	,;
						  { "LQ_NUMERO"		, 2, NIL, 16 }	,;
						  { "LQ_PLIQUI"		, 2, NIL, 17 }	,;
						  { "LQ_PBRUTO"		, 2, NIL, 18 }	,;
						  { "LQ_TPFRET"		, 2, "1=CIF;2=FOB", 19 },;
						  { "LQ_PLACA"		, 2, NIL, 20 }	,;
						  { "LQ_UFPLACA"	, 2, NIL, 21 }	,;
						  { "LQ_FRETE"		, 3, NIL, 22 }	,;
						  { "LQ_SEGURO"		, 3, NIL, 23 }	,;
						  { "LQ_DESPESA"	, 3, NIL, 24 }  }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se o parametro nOpc nao for informado serah inicializado com 3 (inclusao)³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Default nOpc 			:= 3
Default nVlrAcrsFi 		:= 0 	//Variavel que armazrena o acrescimo na venda

//Caso a consulta padrao F3 estiver aberta nao deixara executar
If Type("InConPad") <> "U" .AND. InConPad
	Return .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita as teclas de atalho³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7SetKeys( .F. )
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Desabilita as teclas de atalho³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cOldTpFrete := M->LQ_TPFRET

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inicializa a variavel nItem³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nItem := Len( aCamposAux )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Checa o ponto de entrada para o tratamento dos campos³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If ExistBlock( "LJ7006", .F., .F. ) .AND. !lFtvdVer12
	aCpoUser := ExecBlock( "LJ7006", .F., .F. )

	If ValType( aCpoUser ) == "A"
		For nX := 1 To Len( aCpoUser )
			If aScan( aCamposAux, { |x| AllTrim( Upper( x[1] ) ) == AllTrim( Upper( aCpoUser[nX][1] ) ) } ) == 0
			    If Len( aCpoUser[nX] ) == 2
					AAdd( aCamposAux, { aCpoUser[nX][1], aCpoUser[nX][2], NIL, ( nItem += 1 ) } )
				Else
					AAdd( aCamposAux, { aCpoUser[nX][1], aCpoUser[nX][2], aCpoUser[nX][3], ( nItem += 1 ) } )
				EndIf
			Endif
		Next nX

		aCamposAux := aSort( aCamposAux,,, { |x, y| StrZero( x[2], 2, 0 ) + StrZero( x[4], 2, 0 ) < StrZero( y[2], 2, 0 ) + StrZero( y[4], 2, 0 ) } )
	Endif
Endif

If ExistBlock( "FTVD7006", .F., .F. ) .AND. lFtvdVer12
	aCpoUser := ExecBlock( "FTVD7006", .F., .F. )

	If ValType( aCpoUser ) == "A"
		For nX := 1 To Len( aCpoUser )
			If aScan( aCamposAux, { |x| AllTrim( Upper( x[1] ) ) == AllTrim( Upper( aCpoUser[nX][1] ) ) } ) == 0
			    If Len( aCpoUser[nX] ) == 2
					AAdd( aCamposAux, { aCpoUser[nX][1], aCpoUser[nX][2], NIL, ( nItem += 1 ) } )
				Else
					AAdd( aCamposAux, { aCpoUser[nX][1], aCpoUser[nX][2], aCpoUser[nX][3], ( nItem += 1 ) } )
				EndIf
			Endif
		Next nX

		aCamposAux := aSort( aCamposAux,,, { |x, y| StrZero( x[2], 2, 0 ) + StrZero( x[4], 2, 0 ) < StrZero( y[2], 2, 0 ) + StrZero( y[4], 2, 0 ) } )
	Endif
Endif

//³ Chama a funcao MaFisAlt quando for alteracao de algum produto³
For nX := 1 to Len( aCamposAux )
	SX3->( DbSetOrder( 2 ) )

	If SX3->( DbSeek( PadR( aCamposAux[nX][1], 10 ) ) )
		If X3Uso(SX3->X3_USADO) .AND. cNivel >= SX3->X3_NIVEL
			ADD FIELD aCampos TITULO AllTrim(X3TITULO()) CAMPO AllTrim(SX3->X3_CAMPO) ;
			TIPO SX3->X3_TIPO TAMANHO SX3->X3_TAMANHO DECIMAL SX3->X3_DECIMAL ;
			VALID LJ7ExecGatilhos() .AND. Lj7VldX3() PICTURE PesqPict( "SLQ", SX3->X3_CAMPO ) NIVEL 1 F3 SX3->X3_F3 ;
			BOX IIf( aCamposAux[nX][1]=="LQ_TPFRET", LjBxTpFret(M->LQ_TPFRET), aCamposAux[nX][3] );
			FOLDER aCamposAux[nX][2]WHEN &(SX3->X3_WHEN)

			If M->&( SX3->X3_CAMPO ) == Nil
				M->&( SX3->X3_CAMPO ) := CriaVar( SX3->X3_CAMPO )
			Endif
			AAdd( aCamposAlt,   SX3->X3_CAMPO )
			AAdd( aDadosFrete, { SX3->X3_CAMPO, M->&( SX3->X3_CAMPO ) } )
		Endif
	EndIf
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Analisa os dados de entrega. Pega o default do cadastro de clientes³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aCpoDefault := {	"ENDCOB"	, "BAIRROC"	, "MUNC"	, "CEPC",;
					"ESTC"		, "ENDENT"	, "BAIRROE"	, "MUNE",;
					"CEPE"		, "ESTE" }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se não for a primeira vez que entra nos dados do frete³
//³ Mantem as informacoes digitadas anteriormente         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nX := 1 To Len( aCamposAux )
	If SA1->( ColumnPos( "A1_" + AllTrim( Substr( aCamposAux[nX][1], 4, 7 ) ) ) ) > 0
		If Empty( M->&( aCamposAux[nX][1] ) )
			M->&( aCamposAux[nX][1] ) := &( "SA1->A1_" + AllTrim( Substr( aCamposAux[nX][1], 4, 7 ) ) )
		Endif
	Endif
Next nX

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Cria variavel para controle de alteracao na enchoice e ³
//³ getdados. Quando for um orcamento criado pela rotina de³
//³ reserva nao poderah permitir alteracoes nos dados.     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lAltDados := !( nOpc == 4 .AND. !Empty( SL1->L1_ORCRES ) .AND. !Empty( SL1->L1_FILRES ))

AAdd( aButtons, { "WEB", { || fGeoWizard( "SLQ", M->LQ_CLIENTE + M->LQ_LOJA, { "M->LQ_ENDENT", "M->LQ_MUNE", "M->LQ_ESTE", "M->LQ_CEPE", "M->LQ_BAIRROE" }, { || CodGeoRev( aCoor )[6] <> M->LQ_CEPE } ) }, STR0039, STR0039 } )//"Geoprocessamento"

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define os campos editaveis para interface com usuario³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lLj7086
	aLj7086 := ExecBlock( "LJ7086", .F., .F., {aCamposAlt} )
	If ValType(aLj7086) == "A"
		aCamposAlt := aLj7086
	EndIf
Else
	aLj7086 := aCamposAlt //Caso não tenha o PE, precisa passar os campos do padrão para permitir alteração
EndIf

//Guardar Valor Transp Original
For nX := 1 To Len( aDadosFrete )
	aAdd(aAuxDadFrt, M->&( aDadosFrete[nX][1]))
Next nX

nPosTransp	:= Ascan(aDadosFrete,{|x| Alltrim(Upper(x[1])) == "LQ_TRANSP"})
nPosVeicul	:= Ascan(aDadosFrete,{|x| Alltrim(Upper(x[1])) == "LQ_VEICUL1"})

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Define a tela para interface com usuario³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
DEFINE MSDIALOG oDlgFrete TITLE STR0023 FROM 0,0 TO 325,631 OF oDlgVA PIXEL //"Frete"

Private aGets
Private aTela

oEncFrete := MsMGet():New( 		"SLQ"	, NIL	, IIF( !lAltDados, 2, nOpc )	, NIL	,;
								NIL		, NIL	, aCamposAlt					, NIL	,;
								aLj7086	, NIL	, NIL							, NIL	,;
								NIL		, oDlgFrete	, NIL						, NIL	,;
								NIL		, NIL	, NIL							, .F.	,;
								aCampos	, aFolders )

oEncFrete :oBox:Align := CONTROL_ALIGN_TOP

ACTIVATE DIALOG oDlgFrete CENTERED ON INIT EnchoiceBar( oDlgFrete, { || ( lContinua := .T., oDlgFrete:End() ) }, { || ( oDlgFrete:End() ) },, aButtons )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Faz os tratamentos das informacoes do frete³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lContinua  .AND. !Empty(M->LQ_CODMNEG) .AND. (nFrete <> M->LQ_FRETE .OR. nDespesa <> M->LQ_DESPESA .OR. nSeguro <> M->LQ_SEGURO)
	If MsgYesNo(STR0127)//"Venda com multinegociação, ao alterar o  frete, despesa ou seguro a negociação é desfeita, deseja continuar?"
		Lj7ZeraPgtos()
		nVlrAcrsFi := 0
	Else
		//Negativo as proximas alterações e retorno o valor salvo anteriormente.
		lContinua := .F.
		M->LQ_FRETE 	:= nFrete
		M->LQ_DESPESA 	:= nDespesa
  		M->LQ_SEGURO 	:= nSeguro
	Endif 
EndIf

If lContinua 
	//Limpo o valor do acrescimo na inclusão ou na finalização de um orçamento
    If nOpc == 3  .OR. nOpc == 4
		aAcrescimo[1] := 0					// Valor do acrescimo
		aAcrescimo[2] := 0					// Percentual do acrescimo
		M->LQ_JUROS   := 0
	EndIf

	//Se o inicializador padrao for uma letra (C ou F), gravamos 1 ou 2, pois toda rotina espera esses valores
	If M->LQ_TPFRET == "S"
		M->LQ_TPFRET := "0"
	ElseIf M->LQ_TPFRET == "C"
		M->LQ_TPFRET := "1"
	ElseIf M->LQ_TPFRET == "F"
		M->LQ_TPFRET := "2"
	EndIf

	//Define o tipo de frete padrão como "FOB", caso não tenha sido informado e haja valores de frete, despesa ou seguro.
	If Empty(M->LQ_TPFRET)
		If M->LQ_FRETE + M->LQ_DESPESA + M->LQ_SEGURO > 0
			M->LQ_TPFRET := "2"
		EndIf
	EndIf

	If MaFisFound("NF")
		If M->LQ_TPFRET == "0" //Forço a atualização do tipo de frete quando igual a "Sem frete"
			MafisAlt("NF_TPFRETE", "S")
		ElseIf MafisRet(Nil,"NF_TPFRETE") == "S"	//Caso ja tenha feito a alteração e jude para outro tipo, limpo, pois a verificação e feita no moento do recalculo fiscal no LOJA701C
			MafisAlt("NF_TPFRETE", "")
		EndIf
	EndIf

	For nX := 1 To Len( aDadosFrete )
		aDadosFrete[nX][2] := M->&( aDadosFrete[nX][1] )
	Next nX
	//Verifica se ocorreu alguma mudanca de valores em frete, despesa ou seguro.
	If nOpc == 4 .AND. ((nFrete <> M->LQ_FRETE) .OR. (nDespesa <> M->LQ_DESPESA) .OR. (nSeguro <> M->LQ_SEGURO))
		lFreteAlt := .T.
	EndIf

ElseIf (IIF(!(nPosTransp > 0),.T.,aAuxDadFrt[nPosTransp] <> M->LQ_TRANSP)) .Or. (IIF(!(nPosVeicul > 0),.T.,aAuxDadFrt[nPosVeicul] <> M->LQ_VEICUL1))//Botao Fechar -- verifica se foi alterado

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se foi cancelada a tela restaura as informacoes³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nX := 1 To Len( aAuxDadFrt )
		M->&( aDadosFrete[nX][1] ) := aAuxDadFrt[nX]
	Next nX
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Habilita as teclas de atalho³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
Lj7SetKeys( .T. )

Return ( NIL )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7Tabela ºAutor  ³ Vendas Clientes    º Data ³  18/09/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Define a tabela de preco que sera utilizada                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³void Lj7Tabela()                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7Tabela()
Local cSvAlias 		:= Alias()					// Area original
Local nSvRecno 		:= Recno()                	// Recno da area
Local nX 			:= 0						// Usada em lacos For...Next
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]		// Posicao do percentual de desconto
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do valor de desconto
Local nPosPrcTab	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})	// Posicao do preco de tabela
Local nTabela 		:= 1						// Tabela selecionada no browse
Local aTabelas 		:= {}						// Array com as informacoes do TCBROWSE
Local bTabDlbClick	:= {|| }					// Evento do double click
Local lContinua 	:= .F.						// Indica se continua a execucao da funcao
Local lTrcMoeda     := SuperGetMV("MV_TRCMOED",,.T.)											// Indica se permite escolha de moeda
Local lLJ7043			:= ExistBlock("LJ7043")		// Ponto de entrada para validar a tabela de preco selecionada
Local lLJ7044			:= ExistBlock("LJ7044")		// Ponto de entrada para filtrar as tabelas de preco
Local oDlgTabela								// Objeto dialog principal
Local oTabelas									// Objeto Browse com a listagem de tabelas
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local nMoedaPrv     := 1						// Moeda do Preco de Venda
Local nPosCod		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]		// Posicao do codigo do item
Local nPosBico		:= 0
Local cTabAnt		:= cTabPad					// Guarda a Tabela de preco anterior
Local xRet                                      // Retorno dos pontos de entrada
Local lVAssConc     := LjVassConc()				// Indica se o cliente utiliza a Vda Assistida Concomitante
Local lAutoExA		:= IsBlind()				// Verifica se a rotina sera executada via execauto ou nao

Local lFTVD7043		:= ExistBlock("FTVD7043")	// Ponto de entrada para validar a tabela de preco selecionada
Local lFTVD7044		:= ExistBlock("FTVD7044")	// Ponto de entrada para filtrar as tabelas de preco
Local nPrecoTab		:= 0

Local lAlterProd	:= .F.
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verica Permissões do Usuário³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !(ChkPsw( 32 ))
	Return .F.
Endif

If HasTemplate("PCL")
	nPosBico	:=	aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_BICO"})][2]		// Posicao do bico
	DbSelectArea("LEI")
	LEI->(DbSetOrder(2))

	// Filial + Produto + Bico , usa só o produto pois localizando-o na tabela já é o suficiente para barrar
	If LEI->(MsSeek( xFilial("LEI") + aCols[n][nPosCod] + aCols[n][nPosBico]))
		MsgInfo( STR0084 )//"De acordo com o Requisito XXXV da Legislação PAF-ECF no Ato Cotepe 0608 : Abastecimentos Importados nao podem ter um valor alterado."
		Return .F.
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Monta o array aTabelas                                                   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lCenVenda
	DbSelectArea("SB0")
	DbSetOrder(1)	// Filial + Cod
	If MsSeek( xFilial("SB0") + aCols[n][nPosProd] )
		For nX := 1 to 9
		    If lLJ7044 .AND. !lFtvdVer12
		       xRet := ExecBlock( "LJ7044", .F., .F., {nx} )
			   If ValType(xRet) == "L"
			      If !xRet
			          Loop
			      Endif
		       Endif
		    Endif

		    If lFTVD7044 .AND. lFtvdVer12
	       		xRet := ExecBlock( "FTVD7044", .F., .F., {nx} )
			   If ValType(xRet) == "L"
			      If !xRet
			          Loop
			      Endif
		       Endif
		    Endif

			DbSelectArea("SX3")
			DbSetOrder(2)
			// Checar se o campo da tabela de preços esta 'usado' e o nivel do usuario permite ver o campo
			If MsSeek( PadR("B0_PRV"+Str(nX,1,0),10," ") ) .AND. X3Uso(SX3->X3_USADO) .AND. cNivel >= SX3->X3_NIVEL
				If Empty(SB0->&("B0_DATA"+Str(nX,1,0))) .OR. SB0->&("B0_DATA"+Str(nX,1,0)) >= dDatabase
					aAdd( aTabelas, { StrZero(nX,2,0), SB0->&("B0_PRV"+Str(nX,1,0)) } )
					If cPaisLoc <> "BRA"
					   AAdd(aTabelas[Len(aTabelas)],Capital(SuperGetMV("MV_MOEDA"+LTrim(Str(Max(SB0->&("B0_MOEDA"+Str(nX,1,0)),1))))))
					EndIf
				Endif
			Endif
		Next nX
	Endif
EndIf

If Len(aTabelas) > 0

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Desabilita as teclas de atalho                                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.F.)

	DEFINE MSDIALOG oDlgTabela TITLE STR0024	FROM 0,0 TO 14.5,35 OF oDlgVA //"Tabela de Preços"

	oTabelas := TCBROWSE():New(5,5,100,100, Nil, Nil, {30,30}, oDlgTabela, Nil, Nil, Nil, Nil,bTabDlbClick,,,,,,,,, .T. )

	oTabelas:SetArray( aTabelas )
	ADD COLUMN TO oTabelas HEADER STR0025 	OEM DATA {|| aTabelas[oTabelas:nAt,1] } ALIGN LEFT SIZE 30 PIXELS //"Tabela"
	ADD COLUMN TO oTabelas HEADER STR0026 	OEM DATA {|| Transform(aTabelas[oTabelas:nAt,2],PesqPict("SB0","B0_PRV1")) } ALIGN LEFT SIZE 30 PIXELS //"Preço"
	If cPaisLoc <> "BRA"
	   ADD COLUMN TO oTabelas HEADER STR0032 OEM DATA {|| aTabelas[oTabelas:nAt,3] } ALIGN LEFT SIZE 30 PIXELS //"Moeda"
	EndIf
	oTabelas:nFreeze := 1

	DEFINE SBUTTON FROM 006,108 TYPE 1 ACTION (lContinua := .T. , nTabela := Val(aTabelas[oTabelas:nAt,1]) , ;
	                                           oDlgTabela:End()) ENABLE OF oDlgTabela
	DEFINE SBUTTON FROM 020,108 TYPE 2 ACTION (oDlgTabela:End()) ENABLE OF oDlgTabela

	ACTIVATE MSDIALOG oDlgTabela CENTERED

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita as teclas de atalho                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.T.)
Endif

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ponto de Entrada para validar a tabela de preco selecionada. ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lContinua .AND. lLJ7043 .AND. !lFtvdVer12
	xRet := ExecBlock( "LJ7043", .F., .F., {nTabela} )
	If ValType(xRet) == "L"
		lContinua := xRet
	Endif
Endif

If lContinua .AND. lFTVD7043 .AND. lFtvdVer12
	xRet := ExecBlock( "FTVD7043", .F., .F., {nTabela} )
	If ValType(xRet) == "L"
		lContinua := xRet
	Endif
Endif

If lContinua
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ajusta a variavel que indica a tabela padrao                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	cTabPad := Str( nTabela, 1, 0 )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se e permitido tabela de preco zerada ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If (LjAnalisaLeg(2)[1] .AND. (&("SB0->B0_PRV"+cTabPad)) == 0)
		If !lAutoExA
			LjMsgLeg(LjAnalisaLeg(2))
		EndIf
		cTabPad := cTabAnt
    Else
		If lVAssConc
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ No caso de venda concomitante nao altera o valor do item que ja ³
			//³ foi registrado e somente os proximos a serem registrados 		³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If !lAutoExA
				MsgAlert(STR0049+Chr(13)+STR0050)	//"Para a venda concomitante a mudanca de preco "##"somente influenciara no registro do próximo item"
			Else
				ConOut(STR0049+Chr(13)+STR0050)	//"Para a venda concomitante a mudanca de preco "##"somente influenciara no registro do próximo item"
			EndIf
		Else
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Acerto das colunas da aCols                                              ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			aCols[n][nPosVlUnit] 	:= &("SB0->B0_PRV"+cTabPad)
			aCols[n][nPosDesc]		:= 0
			aCols[n][nPosValDesc]	:= 0

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Acerto das colunas da aColsDet                                              ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			aColsDet[n][nPosPrcTab] := &("SB0->B0_PRV"+cTabPad)

			If lTrcMoeda .AND. !lCenVenda
			   nMoedaPrv := Max(&("SB0->B0_MOEDA" + cTabPad),1)
			   aCols[n][nPosVlUnit]	:= Round(xMoeda(&("SB0->B0_PRV" + cTabPad), nMoedaPrv, nMoedaCor, dDataBase ,;
			                                         nDecimais+1, NIL, nTxMoeda), nDecimais)
			EndIf
			Lj7DefTab(.T.)

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Chama a LJ7VlItem para acerto dos totais na tela                         ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			lAlterProd := .T.
			lj7VlItem( Nil, Nil, Nil, Nil, Nil, Nil, Nil, Nil, lAlterProd )
		EndIf
	EndIf
Endif

If !Empty(cSvAlias)
	DbSelectArea(cSvAlias)
	DbGoto(nSvRecno)
EndIf

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³LJ7ExecGatºAutor  ³ Vendas Clientes    º Data ³  11/19/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Executa gatilhos da tela de frete                          º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701B - Funcao LJ7Frete                                 º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LJ7ExecGatilhos()

If ExistTrigger(SubStr(ReadVar(),4))
	RunTrigger(1)
EndIf

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7VerEst ºAutor  ³ Vendas Clientes    º Data ³  09/12/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a checagem do estoque do produto.                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpL1 := Lj7VerEst( ExpC2, ExpC3, ExpN4, ExpL5 )            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpL1 := Tem ou nao saldo suficiente                        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC2 := Codigo do produto                                  º±±
±±º          ³ExpC3 := Local do produto                                   º±±
±±º          ³ExpN4 := Quantidade a pesquisar                             º±±
±±º          ³ExpL5 := Mostrar ou nao as mensagens. Default = true        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºObservacao³Faz a checagem do valor informado com o saldo em estoque.   º±±
±±º          ³Retorna true se houver saldo disponivel e falso se nao      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7VerEst( cProduto, cLocal, nQuant, lMens,;
					nLinha  , cTesGrava)
Local lRet 			:= .T.								// Retorno da funcao
Local aArea			:= GetArea()						// Salva a area de trabalho
Local cTesPad		:= ""								// Codigo do TES
Local nPosDtTes		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})		// Posicao do Codigo do TES
Local cTesSai  		:= SuperGetMV("MV_TESSAI",,"501")	// Pega do parametro o TES padrao para saida
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]			// Posicao do codigo de produto no aCols
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]			// Posicao da quantidade no aCols
Local nPosDtLocal	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCAL"})		// Posicao do armazem no aColsDet
Local nPosLote      := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOTECTL"})     // Posicao do Lote no aColsDet.
Local nPosSubLote   := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_NLOTE"})       // Posicao do SubLote no aColsDet.
Local nPosDtReserva	:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_RESERVA"})			// Posicao do codigo da reserva
Local nQuanTotal	:= 0								// Soma a Quant. do produto em todas as linhas para ser conferido com o saldo em estoque
Local nX			:= 0								// Contador para o For que varre o aCols
Local cTesInt		:= ""								// Codigo do Tes de saida
Local lAutoExA		:= IsBlind()   						// Verifica se a rotina sera executada via execauto ou nao
Local cRastro		:= SuperGetMV("MV_RASTRO")			// Verifica se a rastreabilidade esta' habilitada.
Local cEstNeg  		:= SuperGetMV("MV_ESTNEG")			// Verifica se e' permitido fazer movimentacoes de estoque com saldo negativo.
Local lEmpPrev 		:= (SuperGetMV("MV_QTDPREV")== "S")	// Verifica se esta baixando empenho previsto.
Local nSaldoSB8     := 0                                // Saldo por lote na tabela SB8.
Local cNumLote      := ""                               // Numero do Lote.
Local cNumSubLote   := ""                               // Numero do SubLote.
Local aQuantLote    := {}                               // Array com as quantidades por lote: 1-Num.Lote, 2-Num.SubLote , 3-Quantidade
Local nQtdLote      := 0                                // Quantidade do lote.
Local nPosScan      := 0                                // Posicao do Ascan no aQuantlote.
Local lValidaEst 	:= .T.
Local lTemRes		:= .F.
Local cArmazem		:= ""
Local nQtdAux 		:= 0

Default lMens		:= .T.								// Mostra ou nao msg durante o processamento
Default nLinha		:= n								// Linha da aCols do produto a ser processado
Default cTesGrava	:= ""								//Informa a TES que sera usada na gravacao, TES Inteligente pode ter sido alterada
Default cLocal		:=""

If Empty(cTesGrava)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Parametro da funcao MaTesInt               ³
	//³ExpN1 = Documento de 1-Entrada / 2-Saida   ³
	//³ExpC1 = Tipo de Operacao Tabela "DF" do SX5³
	//³ExpC2 = Codigo do Cliente ou Fornecedor    ³
	//³ExpC3 = Codigo do gracao E-Entrada         ³
	//³ExpC4 = Tipo de Operacao E-Entrada         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	
	//-----------------------------------------------------------------------------------------------
	// Tratamento para pegar as informações da Tes Inteligente no array estatico caso já tenha sido 
	// consultado na função MaTesInt anteriormente, para melhoria de performance no venda assistida.
	//-----------------------------------------------------------------------------------------------
	nPosTesInt := aScan(aTesInt, {|x| x[1] + x[2] + x[3] == M->LQ_CLIENTE + M->LQ_LOJA + aCols[n][nPosProd] } )
	If nPosTesInt > 0
		cTesInt := aTesInt[nPosTesInt][4]
	Else
		cTesInt := MaTesInt( 2	, "01"						,M->LQ_CLIENTE	, M->LQ_LOJA,;
						 	"C"	, aCols[nLinha][nPosProd]	,NIL			)
						 	
		aAdd(aTesInt, { M->LQ_CLIENTE, M->LQ_LOJA, aCols[n][nPosProd], cTESInt } )
	EndIf	 
Else
	cTesInt	:= cTesGrava
EndIf

If !Empty(cTesInt)
	cTesPad := cTesInt
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se o TES utilizado movimenta ou nao o estoque                   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If ValType( aColsDet ) == "A" .AND. Len( aColsDet ) >= nLinha .AND. !("LR_PRODUTO"$ReadVar())
		cTesPad := aColsDet[nLinha][nPosDtTes]
	Else
		cTesPad := If( Empty( RetFldProd( SB1->B1_COD,"B1_TS" ) ), cTesSai, RetFldProd( SB1->B1_COD,"B1_TS" ) )
	Endif
Endif

SF4->(DbSeek(xFilial("SF4")+cTesPad))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Faz a validacao da quantidade em estoque                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SF4->F4_ESTOQUE == "S"
	DbSelectArea("SB2")
	SB2->(DbSetOrder(1))

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Laco para ler todos os itens do aCols e somar as quantidades do produto do parametro cProduto³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nX := 1 to Len(aCols)
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Se a linha nao estiver deletada³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If !aCols[nX][Len(aCols[nx])]					// se ja possui reserva nao valida estoque
			If ValType(aColsDet) == "A" .AND. Len( aColsDet ) >= nX .AND. !Empty(aColsDet[nX][nPosDtReserva])
				lTemRes := .T.
			Else
				lTemRes := .F.
			EndIf

			If aCols[nX][nPosProd] == cProduto .AND. !lTemRes
				If !Empty(cTesInt)
					cTesPad := cTesInt
				Else
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Verifica se o TES utilizado movimenta ou nao o estoque                   ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If ValType( aColsDet ) == "A" .AND. Len( aColsDet ) >= nX .AND. !("LR_PRODUTO"$ReadVar())
						cTesPad := aColsDet[nX][nPosDtTes]
					Else
						cTesPad := If( Empty( RetFldProd( SB1->B1_COD,"B1_TS" ) ), cTesSai, RetFldProd( SB1->B1_COD,"B1_TS" ) )
					Endif
				Endif

				SF4->(DbSeek(xFilial("SF4")+cTesPad))
				If SF4->F4_ESTOQUE == "S"

					//Ponto de Entrada que permite abortar ou prosseguir com a validacao de estoque do produto.
					//O PE foi colocado neste ponto do fonte para permitir validar Item a Item do produto em questao, caso este seja lancado mais de uma vez na GetDados.
					//Permitindo assim, que mesmo sendo o mesmo produto registrado mais de uma vez, seja possivel validar o estoque de um determinado item e nao validar em outro item.
					If ExistBlock("LJVLDEST")
						If nLinha == nX		// A ultima linha da acols (em edicao) ainda nao esta replicada no aColsDet nesta parte do programa
							cArmazem := cLocal
							nQtdAux  := nQuant
						Else
							cArmazem := aColsDet[nX][nPosDtLocal]
							nQtdAux  := aCols[nX][nPosQuant]
						EndIf
						
						LjGrvLog( NIL , " Antes da Execução do P.E. LJVLDEST ", { aCols[nX][nPosProd], cArmazem, nQtdAux, cTesPad, nX } )
						lValidaEst := ExecBlock("LJVLDEST",.F.,.F.,{ aCols[nX][nPosProd], cArmazem, nQtdAux, cTesPad, nX })
						LjGrvLog( NIL , " Depois da Execução do P.E. LJVLDEST ", lValidaEst )
					EndIf

					If lValidaEst //Valida Estoque

						If nLinha == nX				// A ultima linha da acols ainda nao esta replicada no aColsDet nesta parte do programa
							nQuanTotal += nQuant	// Na linha atual incremento com a quantidade passada como parametro pois a aCols ainda nao foi atualizada devido a validacao do get.
						ElseIf aColsDet[nX][nPosDtLocal] == cLocal
							nQuanTotal += aCols[nX][nPosQuant]
						EndIf

						// Realiza a validacao de saldo por lote (Tabela SB8).
						If cRastro == "S" .AND. cEstNeg == "N" .AND. Len(aColsDet) >= nX .AND. Rastro(aCols[nX][nPosProd])

							cNumLote 	:= aColsDet[nX][nPosLote]
							cNumSubLote := aColsDet[nX][nPosSubLote]

							If cNumSubLote = NIL
								cNumSubLote := ""
							EndIf
							SB8->(DbSetOrder(3)) // B8_FILIAL + B8_PRODUTO + B8_LOCAL + B8_LOTECTL + B8_NUMLOTE
							If !Empty(cNumLote) .AND. SB8->(DbSeek( xFilial("SB8") + aCols[nX][nPosProd] + aColsDet[nX][nPosDtLocal] + cNumLote + cNumSubLote ))
						   		nPosScan := AScan( aQuantLote , { |x| Alltrim(x[1]) == Alltrim(cNumLote) .AND. Alltrim(x[2]) == Alltrim(cNumSubLote) .AND. AllTrim(x[4]) == AllTrim(aColsDet[nX][nPosDtLocal]) } )
						   		If nPosScan > 0
						   			aQuantLote[nPosScan][3] += aCols[nX][nPosQuant]
						   			nQtdLote := aQuantLote[nPosScan][3]
						   		Else
						   			AAdd( aQuantLote , { cNumLote , cNumSubLote , aCols[nX][nPosQuant] , aColsDet[nX][nPosDtLocal] } )
						   			nQtdLote := aQuantLote[Len(aQuantLote)][3]
						   		EndIf

						   		nSaldoSB8  := SB8Saldo(NIL,NIL,NIL,NIL,NIL,lEmpPrev)

								If nSaldoSB8 <  nQtdLote
									If !lAutoExA .AND. lMens
				   						Aviso( STR0075, STR0076 + Alltrim(cNumLote) + STR0077 + Alltrim(cNumSubLote) + STR0078,{STR0079}, 2 )//"Lote", "A quantidade disponível neste lote não é suficiente para suprir a quantidade informada.","Ok"
			   						Else
										ConOut(STR0076 + Alltrim(cNumLote) + STR0077 + Alltrim(cNumSubLote) + STR0078 )
									EndIf
									lRet := .F.
							  	EndIf
							EndIf
						EndIf

					EndIf

				EndIf
			Endif
		Endif
	Next nX
    If nQuanTotal > 0
	    If DbSeek(xFilial("SB2")+ PadR(cProduto,TamSX3("B2_COD")[1],Nil) + cLocal) // No caso de recuperacao cProduto vinha sem os espacos
			If SaldoSB2() < nQuanTotal
				If lMens
					If !lAutoExA
						Aviso( STR0027, STR0028 + cProduto, {STR0003} ) //"Saldo em estoque","Saldo insuficiente em estoque para o produto ","Ok"
					Else
						ConOut(STR0028 + cProduto)
					EndIf
				Endif
				lRet := .F.
			Endif
		Else
			If lMens
				Help(" ", 1, "B2PROD")
			Endif
			lRet := .F.
		Endif
	EndIf
Endif

RestArea( aArea )
Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7ValCli ºAutor  ³ Vendas Clientes    º Data ³  27/12/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a validacao do codigo do cliente informado na enchoice  º±±
±±º          ³da venda assistida                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Lj7ValCli(ExpL1)											  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpL1 - determina se inicializa o array aCrdCliente         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ValCli(lIniCliCRD)
Local lRet 			:= .T.
Local aCpoDefault	:= {}
Local nX 			:= 0																		// Variavel de controle de for
Local lRecalImp     := .F.
Local nPosDtCF		:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"})					// Posicao do Codigo do CF
Local cMV_CLIPAD	:= SuperGetMV("MV_CLIPAD")													// Cliente Padrao
Local cMV_LOJAPAD	:= SuperGetMV("MV_LOJAPAD")													// Loja Padrao
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]		// Posicao da codigo do produto
Local nPosProvEnt	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PROVENT"})				// Posicao da provincia de entrega
Local nTamLQCliente := TamSX3("LQ_CLIENTE")[1]													// Tamanho do campo LQ_CLIENTE
Local lExistCli		:= .F.																		// Controla se existe o cliente digitado
Local lUsaNF		:= .F.																		// Controla se utiliza ou nao NF
Local lExLegSP10	:= .T.									   									// Verifica a existencia da funcao que valida a legislacao paulista que limita o cupom fiscal em 10.000,00
Local lExTotalCF	:= .T.																   		// Verifica a existencia da funcao que calcula o total do cupom fiscal
Local nVlrMerc		:= 0																		//Valor da mercadoria sem descontos
Local lAutoExA		:= IsBlind()																// Verifica se a rotina sera executada via execauto ou nao
Local nBkp			:= 0																// Verifica se a rotina sera executada via execauto ou nao
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]	// Posicao do valor de % desconto
Local nPosVDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do valor de desconto
Local nPosaCols		:= 0								//Salva a posicao do acols
Local cBkpReadVar	:= ""								//salva a variavel contida no ReadVar()
Local lSFinanc    	:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)	// Valida implementação do servico financeiro
Local cMvLjTSf   	:= SuperGetMV("MV_LJTPSF",,"SF")	// Define se é tipo SF
Local lMVLJLBNT		:= SuperGetMV("MV_LJLBNT",,0) > 0//Habilita Finaliza Venda - Vide doc:http://tdn.totvs.com.br/display/PROT/TUXK67_DT_Disponibilizar_Emissao_Nota_Fiscal_Interestadual_Venda_Assistida
//³Release 11.5 - Controle de Formularios (Folios)  ³
//³Chile,Colombia - F1CHI		                    ³
Local lLocR5        :=  cPaisLoc$"CHI|COL"
Local lCFolLocR5	:=	SuperGetMv("MV_CTRLFOL",,.F.) .AND. lLocR5 .AND. !lFiscal
Local cSigEspFo		:=""   																		//Sigla da especie do controle de formulario selecionado - Chile - Release 11.5
Local cDescEspFo	:=""																		//Descricao da especie do controle de formulario selecionado - Chile - Release 11.5
Local lVincPrd		:= .T.
Local cTpFrete 		:= ""
Local lTrocaCli 	:= .F.
Local nDocSai		:= 1
Local lFtvdVer12	:= LjFTVD()				//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local cNomeProg		:= Iif(lFtvdVer12,"FATA701","LOJA701")            //Nome da Rotina
Local lScCsPreco	:= SuperGetMV("MV_SCINTEG",,.F.) .AND. SuperGetMV("MV_SCCSPRC",,.F.) .AND. ExistFunc("LJSCCSPRC") //indica se o Protheus pode consultar o preco de um produto no SIAC Store via WS
Local lDescCab		:= .F.
Local lVAssConc	 	:= LjVassConc()			//Indica se o cliente utiliza a Vda Assistida Concomitante

Default lIniCliCRD  	:= .T.

If nPosProvEnt > 0
	nPosProvEnt	:= aPosCpo[nPosProvEnt][2]		// Posicao da provincia de entrega
EndIf

If nModulo == 5 .AND. !lFtvdVer12
	FTVDValCli()
Else
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Release 11.5 - Controle de Formularios 				 ³
	//³Se for cliente padrao e a especie do formulario		 ³
	//³for igual a FCT-FACTURA ou FCX-FACTURA EXENTA         ³
	//³a venda sera abortada.                                ³
	//³Paises: Chile/Colombia - F1CHI 			             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    If lCFolLocR5

		LjxDadosFo (LjGRecFo(),NIL,@cSigEspFo,@cDescEspFo)

    	If M->LQ_CLIENTE + M->LQ_LOJA == (cMV_CLIPAD + cMV_LOJAPAD).AND. (cSigEspFo=="FCT" .OR. cSigEspFo=="FCX") .AND. cPaisLoc == "CHI"
    		If !lAutoExA
    			MsgAlert(STR0072 + cDescEspFo)//"Cliente padrao não permitido para documento fiscal do tipo "
    		Else
    			Conout(STR0072 + cDescEspFo)//"Cliente padrao não permitido para documento fiscal do tipo "
    		Endif
    		Return .F.
    	EndIf
    EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ A variavel abaixo (cLQCliente) foi criada para controlar a alteracao do  ³
	//³ cliente para os casos em que for digitado F3 e for escolhido o mesmo     ³
	//³ cliente.                                                                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Static cLQCliente := ""
	Static cLQProvEnt := ""

	If Empty(cLQCliente) // Caso esteja vazia esta sendo utilizado portanto cliente e loja padrao.
		If ALTERA
			cLQCliente := SL1->L1_CLIENTE + SL1->L1_LOJA
		Else
			cLQCliente := cMV_CLIPAD + cMV_LOJAPAD
		EndIf
	EndIf

	If lRet
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se foi realmente alterado o cliente  ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cLQCliente <> M->LQ_CLIENTE + M->LQ_LOJA

			//Valida se o cliente da venda pode ser alterado
			lTrocaCli := Lj7TrocCli( lAutoExA , cLQCliente , nTamLQCliente )

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Na validacao do Cod.Cli (M->LQ_LOJA ou M->LQ_CLIENTE ) trato tambem a loja    ³
			//³se a loja atual for valida, mantenho-a.                                       ³
			//³se a loja for invalida atualizo-a com a filial do cliente.                    ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			SA1->(DbSetOrder(1))

			If EMPTY(M->LQ_LOJA) .OR. ( SUBS(cLQCliente,1,nTamLQCliente) <> M->LQ_CLIENTE ) .OR. "LQ_LOJA" $ ReadVar()
				If !( SA1->(DbSeek(xfilial("SA1")+ M->LQ_CLIENTE + M->LQ_LOJA )))
					If SA1->( (DbSeek(xfilial("SA1")+ M->LQ_CLIENTE )) )
						M->LQ_LOJA := SA1->A1_LOJA
						lExistCli	:= .T.
					Endif
				Else
					lExistCli	:= .T.
				EndIf
			EndIf

			If cPaisLoc == "ARG" .AND. Len(aCols) > 0 .AND. !Empty(aCols[n][nPosProd])
				If !lAutoExA
					Aviso(	STR0004,;	//"Atenção"
							STR0055,;	//"No se puede cambiar el cliente despues de cargar los itens."
							{STR0003})	//"OK"
				Else
					ConOut(STR0055)
				EndIf
				Return .F.
			EndIf

			If cPaisLoc == "ARG"
				If SLQ->( ColumnPos("LQ_PROVENT") > 0 )
					If cLQProvEnt <> M->LQ_PROVENT
						M->LQ_PROVENT := If(!Empty(SM0->M0_ESTENT),SM0->M0_ESTENT,SA1->A1_EST)
						For nX := 1 To Len(aCols)
							If !aCols[nX][Len(aCols[nX])]
								If SLR->( ColumnPos("LR_PROVENT") > 0 ) .AND. nPosProvEnt > 0
									M->LR_PROVENT := If(!Empty(SM0->M0_ESTENT),SM0->M0_ESTENT,SA1->A1_EST)
									aCols[nX][nPosProvEnt] := M->LR_PROVENT
									MaFisAlt("IT_PROVENT", aCols[nX][nPosProvEnt], nX)
								EndIf
							EndIf
						Next nX
					EndIf
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica se tem permissao para emitir NF ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		    If cPaisLoc == "BRA" .AND. lExistCli .AND. !lRecebe
				If (M->LQ_CLIENTE + M->LQ_LOJA <> (cMV_CLIPAD + cMV_LOJAPAD)) .OR. LjNFFimVd()
					//se for um caixa NÃO FISCAL, verifica se está apto a emitir NF
					If !lFiscal
						nDocSai := 2
					EndIf
					
					lUsaNF := LjNFFimVd(.T. 			, NIL, NIL	, SA1->A1_EST ,;
										SA1->A1_PESSOA	, Nil, Nil	, nDocSai	)
	  			Else
	  				lUsaNF := .F.
	  			EndIf

		    	If lExTotalCF .AND. lExLegSP10 .AND. !lUsaNF		// A funcao retorna se o cliente tem permissao de emissao de NF
					lRet := Lj950SP10OK(LJXTotalCF(), 2)
					If !lRet
						Return .F.
					EndIf
				EndIf
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Checa a chamada das funcoes fiscais. Se não foi digitado nenhum item     ³
			//³ finaliza com a MafisEnd e inicializa novamente. Se jah existir algum     ³
			//³ item, não permite a troca do cliente.                                    ³
			//³                                                                          ³
			//³ ***** estudar aqui uma forma de recalculo chamando a lj7detalhe() ****** ³
			//³ ***** mas serah necessario avaliar se nao vai ficar mto lento     ****** ³
			//³ ***** devido ao numero de itens vendidos                          ****** ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If	( Lj7T_Total(2) > 0 .OR. Len(aCols) >= 1 .OR. !( Len(aCols) == 1 ) .And.;
			 	( aTail( aCols[1] ) .Or. Empty(aCols[1][nPosProd]) ) ) .AND. cPaisLoc == "BRA"
				
				/***** Alimenta a variavel cLQCliente com o codigo atual   ******/
				cLQCliente := M->LQ_CLIENTE + M->LQ_LOJA

				If SLQ->( ColumnPos("LQ_PROVENT") > 0 )
					cLQProvEnt := M->LQ_PROVENT
				EndIf
				
				MaFisAlt("NF_CODCLIFOR", M->LQ_CLIENTE, NIL, NIL, NIL, NIL, cNomeProg)
				MaFisAlt("NF_LOJA",      M->LQ_LOJA   , NIL, NIL, NIL, NIL, cNomeProg)
				
				//Grava um backup da variavel N do acols
				If !lRecebe //faço o acerto dos totais se nao for recebimento, estava zerando o valor na tela de pagamentos no recebimento
					nPosaCols	:= n
					cBkpReadVar	:= ReadVar()
					__ReadVar	:= "M->LR_PRODUTO"
					Lj7T_Subtotal( 2 , 0)
					For nX := 1 To Len(aColsDet)
						//Altera a variavel N para a posicao do laco
						n := nX
						If !aTail( aColsDet[nX] ) .AND. MaFisFound("IT", nX)
							aColsDet[nX][nPosDtCF] := MaFisRet(nX,"IT_CF")
							
							//Chama a rotina que atualiza os impostos
							Lj7Detalhe( Nil , Nil , .T. , cBkpReadVar )
							
							If lCenVenda .Or. lScCsPreco
								Lj7RegDesc(	aCols[nX][nPosProd]	, lVAssConc	, @aCols		, @aHeader	,;
											aCols[nX][nPosQuant], .F.		, @lDescCab 	, lScCsPreco,;
											/*nKit*/)
								
								/*Necessário devolver o valor da variável pois dentro da Lj7RegDesc/LjDescItem/LjVassConc
								é passado um parametro (nTipoDoc == 1) que zera a variavel de memoria cLQCliente e isso 
								prejudica se houver uma	troca de cliente para o cliente padrão (afetando os recalculos 
								e gravando valores incorretos nas tabelas)*/
								cLQCliente := M->LQ_CLIENTE + M->LQ_LOJA
							EndIf

							If !lCenVenda .And. !lScCsPreco
								Lj7VlItem()
							EndIf
							
							If !lFtvdVer12
								Lj7T_Subtotal( 2, Lj7T_Subtotal(2) + MaFisRet( nX, "IT_TOTAL" ))
							EndIf
						EndIf
					Next nX
					Lj7T_Total(2,Lj7T_SubTotal(2) - Iif(Lj7T_DescV(2)>0, Lj7T_DescV(2), 0))

					If ExistFunc("LjGetnOpcRot")
					 	If LjGetnOpcRot() == 4
							LjGrvLog( M->LQ_NUM , " Lj7ValCli | Atualiza valores do rodape" , )
	
							Lj7T_Total( 2, MaFisRet(nil, "NF_TOTAL"))
							LJ7T_SubTotal( 2, MaFisRet(,"NF_TOTAL") + IIf(ExistFunc("LjNewCalSol") .And. LjNewCalSol(),Lj7T_DescV(2),0 ) )
						EndIf
					Else
						LjGrvLog( M->LQ_NUM , " Lj7ValCli | Nao existe funcao LjGetnOpcRot, atualize LOJA701B" )
					EndIf 

					//Retorna o conteudo da variavel
					n			:= nPosaCols
					__ReadVar	:= cBkpReadVar
				EndIf	

			Else
				If cPaisLoc == "BRA"
					If (MaFisFound("NF") .AND. !lFtvdVer12) .OR. ;
						(MaFisFound("NF") .And. (cLQCliente <> M->LQ_CLIENTE + M->LQ_LOJA) .And. !("LQ_LOJA" $ ReadVar()))
						MaFisEnd()
					Else
						cTpFrete := Lj7TpFrete(M->LQ_CLIENTE,M->LQ_LOJA)

						MaFisIni( M->LQ_CLIENTE, M->LQ_LOJA, "C" , "S" , ;
					          NIL          , NIL        , NIL , .F., ;
					          "SB1"        , cNomeProg  , NIL , NIL, ;
					          NIL          , NIL        , NIL , NIL, ;
					          NIL          , NIL        , NIL , NIL, ;
					          NIL          , NIL        , NIL , NIL, ;
					          NIL          , cTpFrete)
					    LjSatMxFis()
					EndIf

					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Limpa as variaveis do frete quando for alterado o cliente                ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					aCpoDefault := {"ENDCOB" , "BAIRROC" , "MUNC"   , "CEPC" , ;
					                "ESTC"   , "ENDENT"  , "BAIRROE", "MUNE" , ;
					                "CEPE"   , "ESTE"    }

					For nX := 1 to Len(aCpoDefault)
						If SA1->(ColumnPos("A1_"+AllTrim(aCpoDefault[nX])) > 0)
							M->&("LQ_"+aCpoDefault[nX]) := Space(TamSx3("A1_"+aCpoDefault[nX])[1])
						Endif
					Next nX
				Else
					If SubStr(cLQCliente,1,TamSX3("LQ_CLIENTE")[1]) <> M->LQ_CLIENTE
						If !lAutoExA
							LjMsgRun( STR0030,, {|| MaFisRef("NF_CODCLIFOR",cNomeProg,M->LQ_CLIENTE) } ) //"Aguarde ... Recalculando impostos ...."
						Else
							MaFisRef("NF_CODCLIFOR",cNomeProg,M->LQ_CLIENTE)
						EndIf
						lRecalImp := .T.
					EndIf

					If SubStr(cLQCliente,TamSX3("LQ_CLIENTE")[1]+1,TamSX3("LQ_LOJA")[1]) <> M->LQ_LOJA
						If !lAutoExA
							LjMsgRun( STR0030,, {|| MaFisRef("NF_LOJA",cNomeProg,M->LQ_LOJA) } ) //"Aguarde ... Recalculando impostos ...."
						Else
							MaFisRef("NF_LOJA",cNomeProg,M->LQ_LOJA)
						EndIf
						lRecalImp := .T.
					EndIf
				  	If MaFisFound("NF")			// Caso encontre a NF atualiza a provincia do cliente - Localizacoes
						MaFisAlt("NF_PROVENT",If(cPaisLoc == "ARG" .And. !Empty(SM0->M0_ESTENT),SM0->M0_ESTENT,SA1->A1_EST))
					EndIf
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Foi realizado o recalculo dos impostos.      ³
					//³Valoriza os campos de impostos no aColsDet e ³
					//³atualiza interface com o usuario...          ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lRecalImp
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Release 11.5 - Localizacoes                                         ³
						//³Atualizacao dos valores quando o cliente for trocado durante a venda³
						//³Paises: Chile / Colombia - F1CHI 	                               ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If lLocR5 .AND. Len(aColsDet) > 0
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Obter original valor de mercadoria antes de zerar os descontos.³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							nVlrMerc := MAFISRET(,"IT_VALMERC")+Lj7T_DescV(2)
						EndIf

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Zera os desconto da tela, para realizar o novo recalculo³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						Lj7T_DescV(2,0)

						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Release 11.5 - Localizacoes                                         ³
						//³Atualizacao dos valores quando o cliente for trocado durante a venda³
						//³Paises: Chile / Colombia  - F1CHI                                   ³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If lLocR5 .AND. Len(aColsDet) > 0
							Lj7T_DescP(2,0)
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Zera o total, pois dentro da funcao Lj7DescPro ira reconstruir³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							Lj7T_Total ( 2, 0 )
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Proporcionaliza o desconto total nos produtos para que seja realizado³
							//³o recalculo dos impostos variaveis                                   ³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						   	Lj7DescPro(0, nVlrMerc)
							//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
							//³Ajusta o valor do SubTotal.³
							//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
							Lj7T_SubTotal (2, Lj7T_Total(2))
						EndIf

						For nX := 1 To Len(aColsDet)
							If !aColsDet[nX][Len(aColsDet[nX])]  		// Verifica se a linha esta deletada
								MaFisAlt("IT_PROVENT",If(cPaisLoc == "ARG" .And. !Empty(SM0->M0_ESTENT),SM0->M0_ESTENT,SA1->A1_EST),nX)   // Atualiza a provincia do cliente - Localizacoes
								Lj7RecalImp(nX,1)
							EndIf
						Next nX
					EndIf
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Alimenta a variavel cLQCliente com o codigo atual                        ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				cLQCliente := M->LQ_CLIENTE + M->LQ_LOJA
			Endif
			
			If LjNfPafEcf(SM0->M0_CGC)
				If LjConcNota() .AND. !lMVLJLBNT .AND. cLQCliente <> (cMV_CLIPAD + cMV_LOJAPAD)
					LjNFFimVd(.T., NIL, NIL)
				ElseIf !lMVLJLBNT
					LjNFFimVd(.T., .T., NIL)
				EndIf
			EndIf
			
			If CrdxInt() .AND. lIniCliCRD
		       Lj7SetCRDClie()    //Inicializa o array aCrdCliente para forcar a selecao do cartao ou CNPJ/CPF - integracao SIGACRD
		    Endif

		    If cPaisLoc == "BRA"
		    	M->LQ_RECISS := Posicione( "SA1",1,xFilial("SA1")+M->LQ_CLIENTE+M->LQ_LOJA,"A1_RECISS" )
		    EndIf

		    If lFtvdVer12
		    	/*Quando o cliente é alterado e tenha produto no aCols e no aClosDet,
				valida os itens novamente para recalcular o valor dos impostos  */
			    If MaFisFound()
			    	If cPaisLoc == "BRA" .AND. Len(aColsDet) > 0 .And. lTrocaCli
			    		Lj7VlItem()
			    	Else
			    		Lj7Detalhe()
			    		//Zera o valor do Suframa, quando o cliente não for Suframa
			    		If Len(aTotais) > 6 .And. LjVDT_SUFR(2) > 0
		    				LjVDT_SUFR( 2, 0 )
			    		EndIf
			    	EndIf
				Else
			    	Lj7Detalhe()
				EndIf
		    EndIf
		Endif
	EndIf

	//Validacoes de cliente para venda se Servicos Financeiros
	If cPaisLoc == "BRA" .AND. lSFinanc
		//Cliente Padrao
		If M->LQ_CLIENTE + M->LQ_LOJA == cMV_CLIPAD + cMV_LOJAPAD
			//Verifica se existem produtos Servicos Financeiros
			For nX := 1 To Len(aCols)
				If !aCols[nX][Len(aHeader) + 1] .AND. Posicione("SB1", 1, xFilial("SB1") + aCols[nX][nPosProd], "B1_TIPO") == cMvLjTSf
					MsgAlert(STR0108) //#"Essa venda possui ítens de serviço financeiro, antes de mudar para Cliente Padrão será necessário deletá-los"
					Return .F.
				EndIf
			Next nX

			//Verifica se produto possui vinculo com servicos financeiros
			For nX := 1 To Len(aCols)
				MBF->(dbSetOrder(4))

				//Valida se possui cadastro de servico financeiro vigente
				If MBF->(dbSeek(xFilial("MBF") + aCols[nX][nPosProd])) .AND. (dDataBase >= MBF->MBF_DTINI .AND. dDataBase <= MBF->MBF_DTFIM) .AND.;
					!aCols[nX][Len(aHeader) + 1] .AND. lVincPrd

					MsgAlert(STR0109) //#"Essa venda possui ítens vinculados a Serviços Financeiros, verifique se deseja mesmo utilizar o Cliente Padrão"
					lVincPrd := .F.
				EndIf
			Next nX
		EndIf
	EndIf
EndIf

//Aplica regra de desconto se existente, para os itens da venda utilizados na regra.
If lFtvdVer12 .AND. cPaisLoc == "BRA" .AND. lCenVenda .And. !Empty(aCols[n][nPosProd]) .And. nPosDesc > 0 .And. nPosVDesc > 0 .And. Lj7TrocCli( lAutoExA , cLQCliente , nTamLQCliente )
	nBkp:= n
	For nX:=1 to Len(aCols)
		aCols[nx][nPosDesc] := 0
		aCols[nx][nPosVDesc]:= 0
		n:= nX
		Lj7VlItem()
		Lj7Prod(.T.,,.T.)
	Next nX
 	n:= nBkp
EndIf

If !lAutoExA
	oGetva:oBrowse:Refresh()
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7Moeda  ºAutor  ³ Vendas Clientes    º Data ³  07/01/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Permite selecionar a moeda da venda                         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Moeda()

Local nX
Local nMoedaSel   := nMoedaCor
Local nTxMoedaSel := nTxMoeda
Local nBckMoeda   := nMoedaCor
Local nBckTxMoeda := nTxMoeda
Local lEditavel   := SuperGetMV("MV_L1TXMOE",,.T.)						// Indica se a taxa da moeda pode ser alterada na V.Radida
Local lTrcMoeda	  := SuperGetMV("MV_TRCMOED",,.T.)						// Indica se permite escolha de moeda
Local cMoeda      := ""
Local oCBX
Local oTxMoedaSel

If Empty(M->LQ_MOEDA)
   M->LQ_MOEDA  := nMoedaCor
EndIf
If Empty(M->LQ_TXMOEDA)
   M->LQ_TXMOEDA  := nTxMoeda
EndIf
If MaFisFound("NF")
   MaFisAlt("NF_MOEDA",M->LQ_MOEDA)
   MaFisAlt("NF_TXMOEDA",M->LQ_TXMOEDA)
EndIf

If (aMoeda == Nil)
   aMoeda := {}
   For nX := 1	To MoedFin()
      If(!(Empty(SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))))))
         AAdd(aMoeda,SuperGetMV("MV_MOEDA"+Ltrim(STR(nX))))
      Else
         Exit
      Endif
   Next nX
EndIf

If Len(aMoeda) > 1
    cMoeda := aMoeda[nMoedaCor]

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Desabilita as teclas de atalho                                           ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.F.)

	DEFINE MSDIALOG oDlgMoeda TITLE STR0031 FROM 0,0 TO 06,25 OF oDlgVA  //"Moedas"

	@ 003,010 SAY STR0032 SIZE 22, 07 OF oDlgMoeda PIXEL          //"Moeda"
	@ 003,035 COMBOBOX oCBX VAR cMoeda ITEMS aMoeda ON CHANGE ( nTxMoedaSel := RecMoeda(dDataBase,oCBX:nAt),;
              nMoedaSel := oCBX:nAt,;
              Iif(lTrcMoeda,RecMoeda(dDataBase,oCbx:nAt) > 0,.T.));
	          WHEN lEditavel;
	          SIZE 50,50 OF oDlgMoeda PIXEL
    oCBX:cSx1Hlp:="L1_MOEDA"

	@ 015,010 SAY STR0033 SIZE 20, 07 OF oDlgMoeda PIXEL         //"Taxa"
	@ 015,035 MSGET oTxMoedaSel VAR nTxMoedaSel SIZE 50,07 OF oDlgMoeda Picture PesqPict("SL1","L1_TXMOEDA") ;
	           VALID nTxMoedaSel > 0 WHEN lEditavel PIXEL
	oTxMoedaSel:cSx1Hlp:="L1_TXMOEDA"

	DEFINE SBUTTON FROM 030,015 TYPE 1 ACTION ( nMoedaCor := nMoedaSel , nDecimais := MsDecimais(nMoedaCor),;
    											nTxMoeda  := nTxMoedaSel, L7ChgMoeda( nBckMoeda , nBckTxMoeda , lTrcMoeda ),;
    											oDlgMoeda:End()) ENABLE OF oDlgMoeda
	DEFINE SBUTTON FROM 030,050 TYPE 2 ACTION (oDlgMoeda:End()) ENABLE OF oDlgMoeda

	ACTIVATE MSDIALOG oDlgMoeda CENTERED

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Habilita as teclas de atalho                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7SetKeys(.T.)
EndIf

Return .T.

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Programa  ³L7ChgMoeda   ³Autor  ³ Vendas Clientes   ³ Data ³ 08/01/04  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Desc.     ³ Recalcula todo aCols, quando ha alteracao na moeda corrente³±±
±±³          ³ da venda.                                                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpN1 = Moeda anteriormente utilizada                      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ LOJA701                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function L7ChgMoeda(nMoedaAnt, nTxMoedaAnt, lTrcMoeda)

Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local nPosVlrIt 	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]	    // Posicao do Valor Total do Item
Local nPosNumTab	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TABELA"})	// Posicao da tabela
Local nPosPrcTab	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})	// Posicao do preco de tabela
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]		// Posicao do percentual de desconto
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do valor de desconto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]		// Posicao da Quantidade
Local nLin      	:= 0
Local nDesc     	:= 0
Local nIndTab
Local nRegTab
Local nIndSX3   	:= SX3->(IndexOrd())
Local nRegSX3   	:= SX3->(RecNo())
Local nMoedaPrv 	:= 1
Local nLinAux   	:= n
Local cCampo    	:= ""
Local aArea     	:= GetArea()
Local nPrecoTab		:= 0

If (nMoedaCor <> nMoedaAnt .OR. nTxMoeda <> nTxMoedaAnt)
    Lj7SetMoeda(nMoedaCor,nTxMoeda)

	If lTrcMoeda .AND. aTotais[4, 2] > 0
		DbSelectArea("SB0")
		nIndTab := IndexOrd()
		nRegTab := RecNo()
		DbSetOrder(1)

		For nLin := 1 To Len(aCols)
			If !aCols[nLin][Len(aCols[nLin])] .AND. !Empty(aCols[nLin][nPosProd])
				//Valoria a variavel n com a posicao do aCols que esta sendo lida, para que
				//a funcao RunTrigger funcione corretamente
				n := nLin

				lRet := LjxeValPre (@nPrecoTab	, aCols[nLin][nPosProd], M->LQ_CLIENTE, M->LQ_LOJA,;
									nMoedaCor 	, aCols[nLin][nPosQuant])

				If lRet
					//Calcula o novo valor unitario
					aCols[nLin][nPosVlUnit] := nPrecoTab
				Else
					DbSeek(xFilial("SB0")+aCols[nLin][nPosProd])

					cCampo := '"'+"B0_MOEDA"+aColsDet[nLin][nPosNumTab]+'"'
					If ColumnPos(&(cCampo)) > 0
						nMoedaPrv := Max(&(SubStr(cCampo,2,9)),1)
					EndIf

					If (nMoedaCor <> nMoedaPrv) .AND. (nTxMoeda > 0)
						//Calcula o novo valor unitario
						aCols[nLin][nPosVlUnit] := Round(xMoeda(&("B0_PRV"+aColsDet[nLin][nPosNumTab]) , ;
																 nMoedaPrv , nMoedaCor , dDataBase , nDecimais+1 , ;
																 NIL       , nTxMoeda  ),nDecimais)
					Else
						aCols[nLin][nPosVlUnit] := &("B0_PRV"+aColsDet[nLin][nPosNumTab])
					EndIf
				EndIf
				M->LR_VRUNIT := aCols[nLin][nPosVlUnit]

				//Acerta o preco de tabela, para a moeda corrente
				aColsDet[nLin][nPosPrcTab] := aCols[nLin][nPosVlUnit]
				M->LR_PRCTAB := aColsDet[nLin][nPosPrcTab]

				nDesc := aCols[nLin][nPosDesc]
				If nDesc > 0
					aCols[nLin][nPosVlUnit] := NoRound(aColsDet[nLin][nPosPrcTab]-((aColsDet[nLin][nPosPrcTab]*;
												nDesc)/100),nDecimais)
					M->LR_VRUNIT := aCols[nLin][nPosVlUnit]
					aCols[nLin][nPosValDesc] := Round((aColsDet[nLin][nPosPrcTab]*aCols[nLin][nPosQuant])*;
												 nDesc/100,nDecimais)
					M->LR_VALDESC := aCols[nLin][nPosValDesc]
				EndIf
				aCols[nLin][nPosVlrIt] := Round(aColsDet[nLin][nPosPrcTab]*aCols[nLin][nPosQuant],nDecimais)-;
				aCols[nLin][nPosValDesc]
				M->LR_VLRITEM := aCols[nLin][nPosVlrIt]

				If MaFisFound("IT",nLin)
				   MaFisAlt( "IT_PRCUNI" , aCols[nLin][nPosVlUnit] , nLin )
				   Lj7RecalImp( nLin , 2 , "IT_VALMERC" , aCols[nLin][nPosVlrIt] )   //Recalcular os impostos
				   MaFisAlt( "IT_DESCONTO" , aCols[nLin][nPosValDesc] , nLin )
				EndIf
			EndIf
		Next nLin

		//Retorna para o indice e registro originais do SX3
		SX3->(DbSetOrder(nIndSX3))
		SX3->(dbGoTo(nRegSX3))

		//Retorna para o indice e registro originais do SB0
		DbSetOrder(nIndTab)
		dbGoTo(nRegTab)

		n := nLinAux

		Lj7SetPicture()

		Eval(bRefresh)

		//Retorna para a area ativa antes da execucao do rdmake
		RestArea(aArea)
	EndIf
EndIf

Return NIL

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Programa  ³Lj7SetPicture³Autor  ³ Vendas Clientes   ³ Data ³ 138/01/04 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Desc.     ³ Atualiza a Picture considerando a nova moeda da venda      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³                                                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ LOJA701                                                    ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SetPicture()

Local nX		 := 0	// controle de loop
Local cCampoPict := ""

For nX := 1 to 6 //6 - qtde de campos mostrados no aTotais
   If nX == 2
      cCampoPict  := "L1_DESCNF"
   ElseIf nX == 3
      cCampoPict  := "L1_DESCONT"
   Else
      cCampoPict  := "L1_VLRTOT"
   EndIf
   aTotais[nX, 4] := PesqPict("SL1", cCampoPict,,nMoedaCor)
Next nX

Return NIL

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7T_ImpsVºAutor  ³ Vendas Clientes    º Data ³  12/01/2004 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Retorna o total de um determinado tipo ou imposto variavel º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpC1 - Tipo de Imposto                                    º±±
±±º          ³         1 - Discriminado                                   º±±
±±º          ³         2 - Subtrai                                        º±±
±±º          ³         3 - Incluido                                       º±±
±±º          ³ ExpN2 - Tipo de Valor que sera retornado                   º±±
±±º          ³         1 - Base do Imposto                                º±±
±±º          ³         2 - Valor do Imposto                               º±±
±±º          ³ ExpC3 - Nome do Imposto que se deseja as informacoes.      º±±
±±º          ³         Ex: "IVA"                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_ImpsV(cTipoImp, nTipoVal, cImp)
// cTipoImp	=> Tipo de Imposto:
//			   1 - Discriminado (Soma no total da Nota)
//             2 - Subtrai do Total da Nota
//             3 - Incluido (Indiferente)
// nTipoVal	=> Tipo de Valor
//			   1 - Base do Imposto
//			   2 - Valor do Imposto
// cImp     => Codigo do Imposto (Ex: IVA, IV1, etc)

Local nTotal := 0
Local nPos   := 0
Local nX     := 0	//controle de loop

If Type("aTotImpsV") <> "U"

	If cImp <> Nil
		nPos := aScan(aTotImpsV,{|x| Trim(x[1]) == cImp})
		If nPos <> 0
			If nTipoVal == 1
				nTotal := aTotImpsV[nPos][Iif(nTipoVal==1,03,04)]
			Else
				nTotal += aTotImpsV[nPos][Iif(nTipoVal==1,03,04)]
			EndIf
		EndIf
	Else
		For nX := 1 To Len(aTotImpsV)
			If aTotImpsV[nX][05] == cTipoImp
				If nTipoVal == 1
					nTotal := aTotImpsV[nX][Iif(nTipoVal==1,03,04)]
				Else
					nTotal += aTotImpsV[nX][Iif(nTipoVal==1,03,04)]
				EndIf
			EndIf
		Next nX
	EndIf

EndIf

Return( nTotal )

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7DescProºAutor  ³ Vendas Clientes    º Data ³  13/01/2004 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Calcula o desconto proporcional aos itens da venda e       º±±
±±º          ³ executa funcao para recalculo dos impostos variaveis       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1 - Valor do desconto no total da venda                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7DescPro(nVlrDesc, nVlrMerc)

Local nX 		   := 0																			// Controle de loop
Local nPercProduto := 0                                                           				// Desconto Produto
Local nVlDescProp  := 0																			// Desconto proporcional
Local nVlUnit      := 0           																// Valor unitario
Local nVlItem      := 0																			// Valor item
Local nValDescAux  := nVlrDesc																	// Valor desconto
Local nPosVlUnit   := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local nPosVlItem   := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]	   	// Posicao do Valor Total do Item
Local nPosQuant	   := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]		// Posicao da Quantidade
Local nPosProd	   := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]		// Posicao da Quantidade
Local nPosDtDProp  := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_DESCPRO"})				// Posicao do Desconto proporcional
Local nDecsDescPro := TamSX3("L2_DESCPRO")[2]													// Tamanho desconto proporcionalizado
Local nDecVlrUni   := TamSX3("L2_VRUNIT")[2]													// Casas decimais do valor unitario
Local aItens       := {}																		// Itens
Local nMvLjTpDes	:= SuperGetMv( "MV_LJTPDES", , 0 )											// Indica qual desconto sera' utilizado 0 - Antigo / 1 - Novo (objeto)
Local nVlrItDesc	:= 0                                                                    	// Valor de desconto no item
Local nLinDelCols 	:= 0																		// Contador de linhas que nao estao deletadas
Local nJ			:= 0
Local nPosPrcTab		:= Ascan(aPosCpoDet,{|x| Alltrim(Upper(x[1])) == "LR_PRCTAB"})				// Posicao do preco de tabela
Local nPosValDesc  		:= aPosCpo[Ascan(aPosCpo,{|x| Alltrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do desconto
Local lCalcIVA      := .F.                                                                      // Verifica se e' calculo de IVA
Local nCont         := 0                                                                        // Contador de For

Local nVlCalcMerc	:= 0															  			// Valor das mercadorias considerando desconto no item e não considerando desconto global
Local nVlItemUni	:= 0															   			// Valor do item considerando desconto no item se tiver
Local nVlrPerc		:= 100
Local nValDife		:= 0
Local nY			:= 0
Local nPosaItem		:= 0
Local nLastItCalc 	:= 0

Local lIntSynt 	 	:= SuperGetMV("MV_LJSYNT",,"0") == "1"	 // Informa se a integracao Synthesis esta ativa

// Calcula o valor total das mercadorias ja com o desconto...

// Conta o numero de linhas deletadas
For nX := 1 To Len(aCols)

	If lIntSynt
		If Posicione("SB1",1,FWxFilial("SB1")+aCols[nX][nPosProd],"B1_TIPO") == "CG"  //Recargo nao calcula desconto
			Loop
        EndIf
	EndIf

	If aCols[nX][Len(aCols[nX])]
		nLinDelCols++
	EndIf
	If !aCols[nX][Len(aCols[nX])]
		nVlItemUni	:= Iif(!Empty(nVlrDesc) .AND. !Empty(aCols[nX][nPosValDesc]),Round( ((aColsDet[nX][nPosPrcTab] * aCols[nX][nPosQuant]) - aCols[nX][nPosValDesc]) / aCols[nX][nPosQuant],nDecimais),;
					   Iif(Empty(aCols[nX][nPosValDesc]),aColsDet[nX][nPosPrcTab],aCols[nX][nPosVlUnit]))
		nVlCalcMerc	+= (nVlItemUni * aCols[nX][nPosQuant])
	EndIf
End

// Tratamento para calculo que envolva apenas IVA
If cPaisLoc = "ARG"
	For nCont := 1 to Len(aTotImpsV)
		If aTotImpsV[nCont][1]$"IVA"
			lCalcIVA := .T.
		Else
			lCalcIVA := .F.
			Exit
		EndIf
	Next nCont
EndIf

If !lCalcIVA
	nVlrMerc := nVlCalcMerc
	nVlrMerc -= nVlrDesc
Else
	nVlrMerc := nVlCalcMerc
EndIf

For nX := 1 To Len(aCols)
	If !aColsDet[nX][Len(aColsDet[nX])]

		If lIntSynt
			If Posicione("SB1",1,FWxFilial("SB1")+aCols[nX][nPosProd],"B1_TIPO") == "CG"  //Recargo nao calcula desconto
				Loop
	        EndIf
		EndIf

		nJ++
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica a proporcao ref. a cada item da venda                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nVlItemUni	:= Iif(!Empty(nVlrDesc) .AND. !Empty(aCols[nX][nPosValDesc]),A410Arred( ((aColsDet[nX][nPosPrcTab] * aCols[nX][nPosQuant]) - aCols[nX][nPosValDesc]) / aCols[nX][nPosQuant],"L2_VRUNIT",nMoedaCor),;
					   Iif(Empty(aCols[nX][nPosValDesc]),aColsDet[nX][nPosPrcTab],aCols[nX][nPosVlUnit]))

		nPercProduto := ( (nVlItemUni * aCols[nX][nPosQuant]) /  nVlCalcMerc ) * 100
		nVlrPerc	 -= nPercProduto

		// Verifica se foi utilizado 100% em percentual
	   	If nJ == Len(aCols) - nLinDelCols .AND. nVlrPerc <> 0
			nPercProduto += nVlrPerc
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Faco a proporcao do desconto no total para cada item da venda          ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nVlDescProp := (nVlrDesc * nPercProduto) / 100
		nValDescAux -= nVlDescProp
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se todo o desconto foi realmente aplicado											  ³
		//³ Considera a quantidade de linhas deletadas , pois precisa ajustar a diferença na ultima linha ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	   	If nJ == Len(aCols) - nLinDelCols .AND. nValDescAux <> 0
			nVlDescProp += nValDescAux
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Por problemas de arredondamento , o sistema nao deve arredondar os valores no desconto proporcional ,isso ocasiona³
		//³ uma divergencia nos valores de mercadorias quando o campo quantidade era modificado apos ter concedido um desconto³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cPaisLoc == "ARG"
			nVlUnit  := NoRound((nVlItemUni * aCols[nX][nPosQuant] - nVlDescProp) / aCols[nX][nPosQuant],nDecVlrUni)
			nVlItem  := IIf(nVlrDesc == 0, aCols[nX][nPosVlItem] , (nVlItemUni * aCols[nX][nPosQuant] - nVlDescProp) )
		Else
			nVlUnit  := A410Arred((nVlItemUni * aCols[nX][nPosQuant] - nVlDescProp) / aCols[nX][nPosQuant],"L2_VRUNIT",nMoedaCor)

			// Com a nova regra (cPaisLoc <> ARG no LOJXDESC) deve considerar este calcula para chegar no valor unitario
			nVlItem  := IIf(nVlrDesc == 0, aCols[nX][nPosVlItem] ,nVlUnit * aCols[nX][nPosQuant] )
		EndIf
		nVlrMerc -= (nVlItem + nVlDescProp)

		// Soma a diferenca ao último item para que o valor gravado na base coincida com o valor informado na tela...
		If nJ == Len(aCols)- nLinDelCols .AND. ( nVlrMerc <> 0 .AND. ABS(nVlrMerc) < 0.05 ) // Somente para # de centavos
			nVlItem += nVlrMerc
			nVlUnit		:= A410Arred((nVlItem / aCols[nX][nPosQuant]),"L2_VRUNIT",nMoedaCor)
			nValDife	:= (nVlItem - (nVlUnit * aCols[nX][nPosQuant]))
			nVlDescProp -= nVlrMerc
			nVlItem		-= nValDife
			nVlDescProp += nValDife
		EndIf

		AAdd(aItens,{nVlUnit,nVlItem,nVlDescProp,nX})
	EndIf
Next nX

nValDescAux	:= nValDife
nVlDescProp	:= 0
While nValDescAux < -0.01 .OR. nValDescAux > 0.01
	nY++

	If nY > Len(aCols)
		Exit
	Endif

	If !aColsDet[nY][Len(aColsDet[nY])]
		nA := Ascan(aItens,{|x| x[4] == nY})

		If ((aItens[nA][2] * aCols[nY][nPosQuant]) + nValDescAux) >= aColsDet[nY][nPosPrcTab]
			Loop
		EndIf

		nVlItem		:= (aItens[nA][2] + nValDife)
		nVlUnit		:= A410Arred((nVlItem / aCols[nY][nPosQuant]),"L2_VRUNIT")
		nVlDescProp := nValDescAux
		nValDife	:= (nVlItem - (nVlUnit * aCols[nY][nPosQuant]))
		nVlItem		-= nValDife
		nVlDescProp -= nValDife
		nValDescAux	:= nValDife

		aItens[nA][1] := nVlUnit
		aItens[nA][2] := nVlItem
		aItens[nA][3] -= nVlDescProp

	EndIf
End

nJ := 1
For nX := 1 To Len(aCols)
	If !aCols[nX][Len(aCols[nX])]

		If lIntSynt
			If Posicione("SB1",1,FWxFilial("SB1")+aCols[nX][nPosProd],"B1_TIPO") == "CG"  //Recargo nao calcula desconto
				Loop
	        EndIf
		EndIf

		// Acerta o array aColsDet com  o valor do desconto proporcional...
		aColsDet[nX][nPosDtDProp] := aItens[nJ][03]
		nVlDescProp := aColsDet[nX][nPosDtDProp] //Desconto proporcional

		If cPaisLoc <> "BRA"
			nVlDescProp := nVlDescProp + aCols[nX][nPosValDesc] //Desconto proporcional + Desconto no Item
		Else
			// Acerta o valor unitario nas funcoes fiscais...
			MaFisAlt("IT_PRCUNI",aItens[nJ][01],aItens[nJ][04])

			nVlrItDesc := MaFisRet(aItens[nJ][04], "IT_DESCONTO")
	   		If nVlrItDesc > 0
			   MaFisAlt("IT_DESCONTO",0,aItens[nJ][04])
			Endif
		EndIf

		If cPaisLoc <> "BRA"
			MaFisLoad("IT_DESCONTO", nVlDescProp, aItens[nJ][04])
			nLastItCalc := aItens[nJ][04]
		Else
			// Executa o recalculo dos impostos variaveis...
			Lj7RecalImp(aItens[nJ][04],6,"IT_VALMERC",aItens[nJ][02],;
							NIL	,	nVlDescProp )
		EndIf
		nJ++
	EndIf
Next nX

If cPaisLoc <> "BRA"
	If nLastItCalc > 0
		For nX:=1 To Len(aCols)
			If lIntSynt
				If Posicione("SB1",1,FWxFilial("SB1")+aCols[nX][nPosProd],"B1_TIPO") == "CG"  //Recargo nao calcula desconto
					Loop
		        EndIf
			EndIf
			MaFisRecal("IT_DESCONTO",nX)
		Next nX

		For nX:=1 To Len(aCols)
			If lIntSynt
				If Posicione("SB1",1,FWxFilial("SB1")+aCols[nX][nPosProd],"B1_TIPO") == "CG"  //Recargo nao calcula desconto
					Loop
		        EndIf
			EndIf
			MaFisEndLoad(Nx,1)
		Next nX
		StaticCall( MATXFIS, MaIt2cab )
	EndIf

	nX := 1
	While MaFisFound("IT",nX)
		If !MaFisRet( nX, "IT_DELETED" )
			//Recalcula os impostos variaveis (Localizacoes), atualiza array "aTotImpsV"
			Lj7RecalImp(nX,1,,,,,,.T.)
		EndIf
		nX++
	End
EndIf

Return Nil

/*ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7SerieArg  ³ Autor ³ Vendas Clientes       ³Data  ³15/01/04  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Indica a serie da fatura/cupom fiscal dependendo do tipo de   ³±±
±±³          ³ cliente(Loc. Argentina)                                       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe	 ³ ExpC1 := Lj7SerieArg()                                        ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³ ExpC1 := Serie                                                ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso		 ³ Venda Assistida	     									     ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7SerieArg()
Local cTipoCli   := ""    // Tipo do cliente
Local cSerieDoc  := ""    // Serie do documento

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Relacao Tipo de Cliente x Serie  ³
//ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´
//³Tipo Cliente      ³ Serie        ³
//ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´
//³E(Exportacao)   	 ³ E		    ³
//³F(Cons. Final)    ³ B            ³
//³M(Monotrib.)      ³ B            ³
//³N(Resp.Nao Insc.) ³ B            ³
//³S(Nap Sujeito)    ³ B            ³
//³X(Isento) 	     ³ B            ³
//³I(Inscrito)       ³ A            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cTipoCli  := SA1->A1_TIPO
If cTipoCli == "E"
   cSerieDoc := "E"
ElseIf cTipoCli $ "F|M|N|S|X"
   cSerieDoc := "B"
Else
   cSerieDoc := "A"
EndIf

Return cSerieDoc

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7LayAwayºAutor  ³ Vendas Clientes    º Data ³  16/01/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Monta a consulta de lay-away                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7LayAway(aCpoGDaDet)
Local oDlgLay
Local lAllLay	:= .T.
Local lItemaCols:= .F.
Local aArea 	:= GetArea()
Local cFilSLO 	:= xFilial("SLO")
Local aLays		:= {}
Local cCliente 	:= M->LQ_CLIENTE
Local cLoja		:= M->LQ_LOJA
Local aCab		:= { RetTitle("LO_NUMLAY"), RetTitle("LO_ITEM"), RetTitle("LO_PRODUTO"), RetTitle("B1_DESC"),;
                     RetTitle("LO_QUANT") }
Local aSizes	:= {}
Local bLine		:= { || {aLays[oLBx:nAT][1],aLays[oLBx:nAT][2],aLays[oLbx:nAT][3],aLays[oLbx:nAt][4],Transform(aLays[oLbx:nAt][5],PesqPict("SLO","LO_QUANT"))}}
Local lMvLwParc	:= SuperGetMV("MV_LWPARC",,.F.)					     				// Controla se permite entrega parcial do Lay-Away
Local aMvLwParc	:={}				     												// Array com informacoes sobre o Lay-Away para entrega parcial
Local lAutoExA	:= IsBlind()															// Verifica se a rotina sera executada via execauto ou nao
Private cNumLay := ""                                                   				// Numero do Lay-Away

aAdd(aSizes,Max(Len(aCab[1]),TamSx3("LO_NUMLAY")[1]) *4.1)
aAdd(aSizes,Max(Len(aCab[2]),TamSx3("LO_ITEM")[1])   *4.1)
aAdd(aSizes,Max(Len(aCab[3]),TamSx3("LO_PRODUTO")[1])*4.1)
aAdd(aSizes,Max(Len(aCab[4]),TamSx3("B1_DESC")[1])   *4.1)
aAdd(aSizes,Max(Len(aCab[5]),TamSx3("LO_QUANT")[1])  *4.1)

If Empty(cCliente) .OR. Empty(cLoja)
	Return( Nil )
EndIf

// Monta array com as informacoes
DbSelectArea("SLO")
DbSetOrder(2)
DbSeek(cFilSLO+cCliente+cLoja,.T.)
While !SLO->(Eof())  .AND. SLO->LO_FILIAL+SLO->LO_CLIENTE+SLO->LO_LOJA == cFilSLO+cCliente+cLoja

	// A variavel cNumLay e usada no a800Total(). Nao retire.
	cNumLay := SLO->LO_NUMLAY

	// Filtra os vencidos, encerrados, excluidos e aqueles que ainda tem saldo
	If cPaisLoc$"MEX|COL" .AND. ExistFunc("A800LWPARC")
		If !Empty(SLO->LO_CODCON)
			aMvLwParc := a800LwParc(cNumLay,SLO->LO_CODCON)
			If aMvLwParc[1][2] .AND. SLO->LO_VALPAG < a800Total(.T.)
				If SLO->LO_STATUS <> "1" .OR. SLO->LO_DTENT < dDataBase .OR. SLO->LO_VALPAG < aMvLwParc[1][1]
					SLO->(dbSkip())
					Loop
				EndIf
			ElseIf !aMvLwParc[1][2] .AND. SLO->LO_VALPAG >= a800Total(.T.)
				If SLO->LO_STATUS <> "1" .OR. SLO->LO_DTENT < dDataBase
					SLO->(dbSkip())
					Loop
				EndIf
			ElseIf !aMvLwParc[1][2] .AND. SLO->LO_VALPAG < a800Total(.T.)
				SLO->(dbSkip())
				Loop
			Else
				If SLO->LO_STATUS <> "1" .OR. SLO->LO_DTENT < dDataBase .OR. SLO->LO_VALPAG < a800Total(.T.)
	    			SLO->(dbSkip())
					Loop
				EndIf
			EndIf
		Else
			If SLO->LO_STATUS <> "1" .OR. SLO->LO_DTENT < dDataBase .OR. SLO->LO_VALPAG < a800Total(.T.)
	    		SLO->(dbSkip())
				Loop
			EndIf
		EndIf
	Else
		If SLO->LO_STATUS <> "1" .OR. SLO->LO_DTENT < dDataBase .OR. SLO->LO_VALPAG < a800Total(.T.)
	    	DbSkip()
			Loop
		EndIf
	EndIf

	//Verifica se o item ja esta no aCols
    lItemaCols := Lj7ItemLay(cNumLay,SLO->LO_ITEM)

    If lItemaCols
	   SLO->(dbSkip())
	   Loop
    EndIf

	AADD(aLays,{SLO->LO_NUMLAY,SLO->LO_ITEM,SLO->LO_PRODUTO,a800DescB1(SLO->LO_PRODUTO),(SLO->LO_QUANT-SLO->LO_QUJE)})
	SLO->(dbSkip())
End

RestArea(aArea)

If cPaisLoc$"MEX|COL"
		// Monta Dialog
	If !Empty(aLays)
		DEFINE MSDIALOG oDlgLay FROM 02,10 To 18,82.5 of oDlgVA
		oLbx := TWBrowse():New(0.5, 0.5,280,90,,aCab,aSizes,oDlgLay,,,,,,,,,,,, .F.,, .F.,, .F.,,, )
		oLbx:SetArray(aLays)
		oLbx:bLine := bLine
		DEFINE  SButton FROM 100,215 TYPE 1 Action (Lj7FillLay(oLbx,.F.,aCpoGDaDet),oDlgLay:End() ) ENABLE OF oDlgLay  PIXEL
		DEFINE  SButton FROM 100,250 TYPE 2 Action (oDlgLay:End() ) ENABLE OF oDlgLay  PIXEL
		ACTIVATE DIALOG oDlgLay
	Else
		If !lAutoExA
			Aviso(STR0035,STR0036 + CRLF +; //"Atencao"###"Nao foram encontrados registros de Lay-Away com os dados especificados."
	  			  STR0037,{STR0003})   //"Verifique o cliente e o status do Lay-Away."###"Ok"
	  	Else
	  	    Conout(STR0036 + CRLF + STR0037)
	  	Endif
	Endif
Else
	// Monta Dialog
	If !Empty(aLays)
		DEFINE MSDIALOG oDlgLay FROM 02,10 To 18,82.5 of oDlgVA
		oLbx := TWBrowse():New(0.5, 0.5,280,90,,aCab,aSizes,oDlgLay,,,,,,,,,,,, .F.,, .F.,, .F.,,, )
		oLbx:SetArray(aLays)
		oLbx:bLine := bLine
		IF lMvLwParc
			// Somente permite a escolha se o parametro permitir layaway parcial
			@ 105,25 CHECKBOX oItem VAR lAllLay PROMPT STR0034 SIZE 90,8 OF oDlgLay   //"Utiliza todo o Lay-Away"
	    EndIF
		DEFINE  SButton FROM 100,215 TYPE 1 Action (Lj7FillLay(oLbx,lAllLay,aCpoGDaDet),oDlgLay:End() ) ENABLE OF oDlgLay  PIXEL
		DEFINE  SButton FROM 100,250 TYPE 2 Action (oDlgLay:End() ) ENABLE OF oDlgLay  PIXEL
		ACTIVATE DIALOG oDlgLay
	Else
		If !lAutoExA
		    Aviso(STR0035,STR0036 + CRLF +; //"Atencao"###"Nao foram encontrados registros de Lay-Away com os dados especificados."
		          STR0037,{STR0003})   //"Verifique o cliente e o status do Lay-Away."###"Ok"
		Else
			ConOut(STR0036 + CRLF + STR0037)
		Endif
	Endif
EndIf

Return( Nil )

/*/
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao	 ³Lj7ItemLay   ³ Autor ³ Vendas Clientes       ³Data  ³16/01/04  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Verifica se o item do Lay-Away ja esta no aCols               ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe	 ³ ExpL1 := Lj7ItemLay(ExpC2,ExpC3)                              ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ ExpL1 - Controla se o item do LY esta no aCols				 ³±±
±±³          ³ ExpC2 - Numero do Lay-Away                                    ³±±
±±³          ³ ExpC3 - Item do Lay-Away                                      ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso		 ³ Venda Assistida	     									     ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
/*/
Static Function Lj7ItemLay(cNumLay, cItemLay)

Local lItemaCols := .F.                                                     // Controla se o item do Lay-Away ja estah no aCols
Local nX         := 1                                                       // Controle do loop
Local nPosLay    := Ascan(aPosCpoDet,{|x| AllTrim(x[1]) == "LR_NUMLAY"}) 	// Posicao do numero do Lay-Away
Local nPosItLay  := Ascan(aPosCpoDet,{|x| x[1] == "LR_ITEMLAY"})	        // Posicao do item do Lay-Away
Local nPosProd	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]      // Posicao do Codigo do produto

While nX <= Len(aCols) .AND. !lItemaCols
   If (aCols[nX][Len(aCols[nX])]) .OR. Empty(aCols[nX][nPosProd])
      nX++
	  Loop
   EndIf
   If nPosLay > 0 .AND. nPosItLay > 0
      If cNumLay == aColsDet[nX][nPosLay] .AND. cItemLay == aColsDet[nX][nPosItLay]
         lItemaCols := .T.
      EndIf
   EndIf
   nX++
End

Return (lItemaCols)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7FillLayºAutor  ³ Vendas Clientes    º Data ³  16/01/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz o preenchimento do aCols com  os itens do Lay-Away sele-º±±
±±º          ³cionado                                                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7FillLay(oLbx, lAllLay, aCpoGDaDet)

Local aArea 	    := GetArea()              // Area atual
Local aColsTmp	    := {}                     // aCols temporario para fins de backup
Local aColsDetTmp   := {}                     // aColsDet temporario para fins de backup
Local nLinTmp       := n                      // Linha corrente temporaria para fins de backup
Local naCols        := 0                      // Indice do item no aCols
Local nX            := 0                      // Controle de loop
Local nPosItem		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})][2]	   		// Posicao do numero do item
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2] 		// Posicao da codigo do produto
Local nPosDescri	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESCRI"})][2]  		// Posicao da Descricao do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]   		// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local nPosVlItem    := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]		// Posicao do Valor Total do Item
Local nPosUM		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_UM"})][2]			// Posicao da Unidade de Medida
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]			// Posicao do percentual de desconto
Local nPosTES       := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TES"})	// Posicao do TES
Local nPosCF        := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_CF"})		// Posicao do CF
Local nPosTabela    := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_TABELA"})	// Posicao da tabela
Local nPosLocal     := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_LOCAL"})	// Posicao do Local
Local nPosLay       := Ascan(aPosCpoDet,{|x| AllTrim(x[1]) == "LR_NUMLAY"}) 		// Posicao do numero do Lay-Away
Local nPosItLay     := Ascan(aPosCpoDet,{|x| x[1] == "LR_ITEMLAY"})	            // Posicao do item do Lay-Away
Local nVlrSubTotal  := 0                        // Valor a ser apresentado no sub-total
Local nItem         := 0                        // Item da venda
Local nTamItem      := TamSX3("LR_ITEM")[1]     // Tamanho do campo LR_ITEM
Local cItem		    := oLbx:aArray[oLbx:nAt][2] // Item do Lay-Away
Local cCampo        := ""                        // Nome do campo para carregar aColsDet
Local lItemaCols    := .F.                      // Controla se o item do Lay-Away ja estah no aCols
Local lInsLinha     := .F.                      // Controla se deve inserir linha no aCols
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local cNomeProg	:= Iif(lFtvdVer12,"FATA701","LOJA701")	//Nome da Rotina

Private cNumLay	:= oLbx:aArray[oLbx:nAt][1]    // Numero do Lay-Away

SLO->(DbSetOrder(1))
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Carrega o aColsDet                                           ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aAdd( aColsDet, Array( Len(aCpoGDaDet) + 1 ) )
For	nX := 1 to Len(aCpoGDaDet)
   cCampo := "L2_" + AllTrim(Substr(aCpoGDaDet[nX],4,Len(aCpoGDaDet[nX])))
   aColsDet[Len(aColsDet)][nX] := FieldGet(ColumnPos(cCampo))
Next nX
aColsDet[Len(aColsDet)][Len(aCpoGDaDet) + 1] := .F.
lLayAway     := .T.
M->LQ_CONDPG := "LAY"

If lAllLay
	SLO->(DbSeek(xFilial("SLO")+cNumLay,.T.))

    If !MaFisFound("NF")
       MaFisIni( SLO->LO_CLIENTE, SLO->LO_LOJA, "C", "S", Nil, Nil, Nil, .F., "SB1", cNomeProg )
       LjSatMxFis()
    Endif

    SA1->(DbSetOrder(1))
    SA1->(DbSeek(xFilial("SA1")+SLO->LO_CLIENTE+SLO->LO_LOJA))

	naCols      := Len(aCols)
	aColsTmp    := aClone(aCols[1])
	aColsDetTmp := aClone(aColsDet[1])
	nItem       := naCols

	// Preenche o aCols
	While !(SLO->(EOF())) .AND. xFilial("SLO")+cNumLay == SLO->LO_FILIAL+SLO->LO_NUMLAY
		// Filtra os vencidos, encerrados, excluidos e aqueles que ainda tem saldo
		If cPaisLoc <> "MEX"
			If SLO->LO_STATUS <> "1" .OR. SLO->LO_DTENT < dDataBase .OR. SLO->LO_VALPAG < a800Total(.T.)
				SLO->(DbSkip())
				Loop
			EndIf
		EndIf

        lItemaCols  := Lj7ItemLay(SLO->LO_NUMLAY,SLO->LO_ITEM)

        If lItemaCols
	       SLO->(DbSkip())
	       Loop
        EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Chama as funcoes fiscais                                     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If MaFisFound("NF")
			MaFisAdd( SLO->LO_PRODUTO,;		    	// Produto
						SLO->LO_TES,;				// Tes
						SLO->LO_QUANT,;	    		// Quantidade
						SLO->LO_VUNIT,;  			// Preco unitario
						SLO->LO_VALDESC,;			// Valor do desconto
						"",; 						// Numero da NF original
						"",; 						// Serie da NF original
						0,;							// Recno da NF original
						0,; 						// Valor do frete do item
						0,; 						// Valor da despesa do item
						0,; 						// Valor do seguro do item
						0,; 						// Valor do frete autonomo
						SLO->LO_TOTAL + IIf(cPaisLoc == "BRA", SLO->LO_VALDESC, 0),; //SL2->L2_PRCTAB * SL2->L2_QUANT,;			// Valor da mercadoria
						0 )							// Valor da embalagem
		Endif
        nVlrSubTotal += MaFisRet( nItem, "IT_TOTAL" )
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Atualizacao do aCols                                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nPosItem > 0
			aCols[naCols][nPosItem ]:= StrZero(nItem,nTamItem)
			M->LR_ITEM	            := StrZero(nItem,nTamItem)
		EndIf

		If nPosProd > 0
			aCols[naCols][nPosProd]	:= SLO->LO_PRODUTO
			M->LR_PRODUTO	        := SLO->LO_PRODUTO
		EndIf

		If nPosDescri > 0
		    SB1->(DbSetOrder(1))
		    If SB1->(DbSeek(xFilial("SB1")+SLO->LO_PRODUTO))
			   aCols[naCols][nPosDescri] := SB1->B1_DESC
		 	   M->LR_DESCRI	             := SB1->B1_DESC
		 	EndIf
		EndIf

		If nPosQuant > 0
			aCols[naCols][nPosQuant]:= SLO->LO_QUANT - SLO->LO_QUJE
			M->LR_QUANT			     := SLO->LO_QUANT - SLO->LO_QUJE
		EndIf

		If nPosVlUnit > 0
			aCols[naCols][nPosVlUnit]:= SLO->LO_VUNIT
			M->LR_VRUNIT	          := SLO->LO_VUNIT
		EndIf

		If nPosVlItem > 0
			aCols[naCols][nPosVlItem] := SLO->LO_TOTAL
			M->LR_VLRITEM	           := SLO->LO_TOTAL
		EndIf

		If nPosUM > 0
			aCols[naCols][nPosUM] := SLO->LO_UM
			M->LR_UM		       := SLO->LO_UM
		EndIf

		If nPosDesc > 0
			aCols[naCols][nPosDesc]	:= SLO->LO_DESC
			M->LR_DESC		        := SLO->LO_DESC
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Atualizacao do aColsDet                                      ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nPosItem > 0
			aColsDet[naCols][nPosItem]	:= StrZero(nItem,nTamItem)
		EndIf

		If nPosProd > 0
			aColsDet[naCols][nPosProd]	:= SLO->LO_PRODUTO
		EndIf

		If nPosLocal > 0
			aColsDet[naCols][nPosLocal]	:= SLO->LO_LOCAL
			M->LR_LOCAL					:= SLO->LO_LOCAL
		EndIf

		If nPosTES > 0
			aColsDet[naCols][nPosTES]	:= SLO->LO_TES
			M->LR_TES					:= SLO->LO_TES
		EndIf

		If nPosCF > 0
		    SF4->(DbSetOrder(1))
		    If SF4->(DbSeek(xFilial("SF4")+SLO->LO_TES))
			   aColsDet[naCols][nPosCF]	:= SF4->F4_CF
			   M->LR_CF					:= SF4->F4_CF
		    EndIf
		EndIf

		If nPosTabela > 0
			aColsDet[naCols][nPosTabela]	:= cTabPad
			M->LR_TABELA					:= cTabPad
		EndIf

		If nPosLay > 0
			aColsDet[naCols][nPosLay]	:= SLO->LO_NUMLAY
			M->LR_NUMLAY				:= SLO->LO_NUMLAY
		EndIf

    	If nPosItLay > 0
			aColsDet[naCols][nPosItLay] := SLO->LO_ITEM
			M->LR_ITEMLAY	             := SLO->LO_ITEM
		EndIf
		//Certificar que o item selecionado do Lay-Away esteja como nao-deletado no aCols
		aCols[naCols][Len(aCols[naCols])]	          := .F.
		aColsDet[naCols][Len(aColsDet[naCols])]      := .F.
		AADD( aCols   , aClone( aColsTmp ) )
		AADD( aColsDet, aClone( aColsDetTmp ) )

        Lj7RecalImp(naCols,2,"IT_TES",SLO->LO_TES)   //Recalcular os impostos

		naCols++
        //Validacao do produto
		Lj7Prod(.F.)
		n		  := naCols
		lInsLinha := .T.
        nItem++

		DbSelectArea("SLO")
		DbSkip()
	End
	If lInsLinha
       naCols    := Len(aCols)-1
	   Asize(aCols,naCols)
	   Asize(aColsDet,naCols)

	   Lj7SetMoeda(SLO->LO_MOEDA,SLO->LO_TXMOEDA)
	EndIf
Else
	SLO->(DbSeek(xFilial("SLO")+cNumLay+cItem))

    If !MaFisFound("NF")
       MaFisIni( SLO->LO_CLIENTE, SLO->LO_LOJA, "C", "S", Nil, Nil, Nil, .F., "SB1", cNomeProg )
       LjSatMxFis()
    Endif

    SA1->(DbSetOrder(1))
    SA1->(DbSeek(xFilial("SA1")+SLO->LO_CLIENTE+SLO->LO_LOJA))

If cPaisLoc$"MEX|COL"
	If n == 1 .AND. Empty(aCols[1][nPosProd])
		naCols := 1
	Else
		oGetVA:AddLine()
		naCols := Len(aCols)
	EndIf
Else
	naCols := Len(aCols)
EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Chama as funcoes fiscais                                     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If MaFisFound("NF")
	   MaFisAdd( SLO->LO_PRODUTO,;		    // Produto
	             SLO->LO_TES,;				// Tes
				 SLO->LO_QUANT,;	    	// Quantidade
				 SLO->LO_VUNIT,;  			// Preco unitario
				 SLO->LO_VALDESC,;			// Valor do desconto
				 "",; 						// Numero da NF original
				 "",; 						// Serie da NF original
				 0,;						// Recno da NF original
				 0,; 						// Valor do frete do item
				 0,; 						// Valor da despesa do item
				 0,; 						// Valor do seguro do item
				 0,; 						// Valor do frete autonomo
				 SLO->LO_TOTAL + IIf(cPaisLoc == "BRA", SLO->LO_VALDESC, 0),; 	// Valor da mercadoria
				 0 )						// Valor da embalagem
	Endif
	Lj7SetMoeda(SLO->LO_MOEDA,SLO->LO_TXMOEDA)

    nVlrSubTotal := MaFisRet( naCols, "IT_VALMERC" )
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualizacao do aCols                                         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nPosItem > 0
	   aCols[naCols][nPosItem ]:= StrZero(naCols,nTamItem)
	   M->LR_ITEM	            := StrZero(naCols,nTamItem)
	EndIf

	If nPosProd > 0
		aCols[naCols][nPosProd]	:= SLO->LO_PRODUTO
		M->LR_PRODUTO	        := SLO->LO_PRODUTO
	EndIf

	If nPosDescri > 0
	   SB1->(DbSetOrder(1))
	   If SB1->(DbSeek(xFilial("SB1")+SLO->LO_PRODUTO))
	      aCols[naCols][nPosDescri]:= SB1->B1_DESC
		  M->LR_DESCRI	            := SB1->B1_DESC
	   EndIf
	EndIf

	If nPosQuant > 0
		aCols[naCols][nPosQuant] := SLO->LO_QUANT - SLO->LO_QUJE
		M->LR_QUANT			      := SLO->LO_QUANT - SLO->LO_QUJE
	EndIf

	If nPosVlUnit > 0
		aCols[naCols][nPosVlUnit] := SLO->LO_VUNIT
		M->LR_VRUNIT	           := SLO->LO_VUNIT
	EndIf

	If nPosVlItem > 0
		aCols[naCols][nPosVlItem] := SLO->LO_TOTAL
		M->LR_VLRITEM	           := SLO->LO_TOTAL
	EndIf

	If nPosUM > 0
		aCols[naCols][nPosUM] := SLO->LO_UM
		M->LR_UM		       := SLO->LO_UM
	EndIf

	If nPosDesc > 0
		aCols[naCols][nPosDesc]	:= SLO->LO_DESC
		M->LR_DESC		        := SLO->LO_DESC
	EndIf

    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Atualizacao do aColsDet                                      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nPosItem > 0
	   aColsDet[naCols][nPosItem ]:= StrZero(naCols,nTamItem)
	EndIf

    If nPosProd > 0
	   aColsDet[naCols][nPosProd] := SLO->LO_PRODUTO
    EndIf

	If nPosLocal > 0
		aColsDet[naCols][nPosLocal] := SLO->LO_LOCAL
		M->LR_LOCAL		             := SLO->LO_LOCAL
	EndIf

	If nPosTES > 0
		aColsDet[naCols][nPosTES] := SLO->LO_TES
		M->LR_TES		           := SLO->LO_TES
	EndIf

    If nPosCF > 0
	   SF4->(DbSetOrder(1))
	   If SF4->(DbSeek(xFilial("SF4")+SLO->LO_TES))
	      aColsDet[naCols][nPosCF]  := SF4->F4_CF
		  M->LR_CF		             := SF4->F4_CF
	   EndIf
    EndIf

    If nPosTabela > 0
	   aColsDet[naCols][nPosTabela] := cTabPad
	   M->LR_TABELA                  := cTabPad
	EndIf

	If nPosLay > 0
		aColsDet[naCols][nPosLay] := SLO->LO_NUMLAY
		M->LR_NUMLAY	           := SLO->LO_NUMLAY
	EndIf

   	If nPosItLay > 0
		aColsDet[naCols][nPosItLay] := SLO->LO_ITEM
		M->LR_ITEMLAY	             := SLO->LO_ITEM
	EndIf

    //Validacao do produto
	Lj7Prod(.F.)

	For nX := 1 to Len(aCols)-1
	   If aCols[nX][Len(aCols[nX])]
	      Loop
	   EndIf
	   nVlrSubTotal += aCols[nX][nPosVlItem]
	Next nX
	nVlrSubTotal += Lj7T_ImpsV("1",2)
EndIf

Lj7T_SubTotal( 2, nVlrSubTotal )
Lj7T_Total( 2, Lj7T_SubTotal(2) - Lj7T_DescV(2) )

RestArea(aArea)

If cPaisLoc$"MEX|COL"
	n := naCols
	oGetVA:Refresh()
Else
	n := nLinTmp
EndIf

Return NIL

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7SetMoedºAutor  ³ Vendas Clientes    º Data ³  20/01/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Atualiza as variaveis de moeda e sua taxa correspondente    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7SetMoeda(nMoedaAtu, nTxMoedaAtu)

M->LQ_MOEDA  := Max(nMoedaAtu,1)
M->LQ_TXMOEDA:= nTxMoedaAtu
nMoedaCor    := M->LQ_MOEDA
nTxMoeda     := M->LQ_TXMOEDA
nDecimais    := MsDecimais(nMoedaCor)
If MaFisFound("NF")
	If cPaisLoc == "ARG"
		//Executa MafisLoad para carregar o valor ao inves de MaFisAlt, para melhorar a performance pois a MatxFis executa recalculo quando efetua MafisAlt
		MaFisLoad("NF_MOEDA",M->LQ_MOEDA)
		MaFisLoad("NF_TXMOEDA",M->LQ_TXMOEDA)
	Else
		MaFisAlt("NF_MOEDA",M->LQ_MOEDA)
		MaFisAlt("NF_TXMOEDA",M->LQ_TXMOEDA)
	EndIf
EndIf

Return NIL

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ LJ7_ValDesc  ³ Autor ³ Vendas Clientes      ³ Data ³ 19/05/2004 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Verifica se o vendedor pode dar desconto, caso contrário pede a ³±±
±±³          ³ senha do supervisor para liberação do desconto                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³ SigaLoja                                                        ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7_ValDesc(nTipo, nPerDesc, nVlrDesc)

Local lRet       := .T.										// Retorno da funcao
Local cAutorDesc := ""										// Autor do desconto
Local aDesc      := {"V", 0}								// Desconto
Local lLj7018    := ExistBlock("LJ7018")					// Verifica se tem ponto de entrada.
Local nX		 := 0										// Contador
Local cFormDesc  := SuperGetMV( "MV_LJFORMD", .F., "1" )	// Caso nao exista o parametro assume "1" como DEFAULT
Local nPosPerDes := GdFieldPos("LR_DESC")					// Guarda posicao do campo LR_QUANT para procura no aCols										// Posicao do percentual de desconto
Local nPosVlrDes := GdFieldPos("LR_VALDESC")				// Posicao do valor do desconto
Local nPercAux   := 0
Local lFTVD7018  := ExistBlock("FTVD7018")					// Verifica se tem ponto de entrada.
Local lCtrlB	 := .T.										// Indica para a funcao LjProfile que a chamada foi das tecla <CTRL>+B
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida


If (nPerDesc > 0) .OR. (nVlrDesc > 0)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Considera os descontos efetuados no aCols qdo realizado³
	//³no total                                               ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Len( aCols ) > 0 .AND. ( nPosPerDes > 0 .AND. nPosVlrDes > 0 )

		For nX := 1 To Len(aCols)
			If !aCols[nX][Len(aCols[nX])]
				If aCols[nX][nPosPerDes] > nPercAux
					nPercAux := aCols[nX][nPosPerDes]
				EndIf
				nVlrDesc += aCols[nX][nPosVlrDes]
			EndIf
	    Next nX

	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Soma maior percentual de desconto do item com o percentual de desconto global.³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nPerDesc += nPercAux

	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Com a soma dos percentuais , valida o maximo permitido ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	    If nPerDesc > 99.99
			nPerDesc := 99.99
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Valor do desconto nao permitido para o caixa atual / Desconto nao autorizado³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lLj7018 .AND. !lFtvdVer12

		lRet := ExecBlock("LJ7018",.F.,.F.,{ nPerDesc , nVlrDesc, nTipo })

	ElseIf !lFtvdVer12

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se o considera % OU valor de desconto, ou, ³
		//³% E valor de desconto                               ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cFormDesc == "1"
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Tipo de validacao determinado pelo parametro MV_LJTPDES³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nTipo == 1
				aDesc := { "P", nPerDesc }
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Tipo de validacao determinado pelo parametro MV_LJTPDES ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			ElseIf nTipo == 2
				aDesc := { "V", nVlrDesc }
			EndIf

			lRet := LJProfile(11, @cAutorDesc, aDesc, nPerDesc, nVlrDesc,Nil,Nil,lCtrlB)

		ElseIf cFormDesc == "2"

			lRet := LJProfile(11, @cAutorDesc, aDesc, nPerDesc, nVlrDesc,Nil,Nil,lCtrlB)

    	EndIf
	Endif

	If lFTVD7018 .AND. lFtvdVer12

		lRet := ExecBlock("FTVD7018",.F.,.F.,{ nPerDesc , nVlrDesc, nTipo })

	ElseIf lFtvdVer12

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se o considera % OU valor de desconto, ou, ³
		//³% E valor de desconto                               ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cFormDesc == "1"
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Tipo de validacao determinado pelo parametro MV_LJTPDES³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If nTipo == 1
				aDesc := { "P", nPerDesc }
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Tipo de validacao determinado pelo parametro MV_LJTPDES ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			ElseIf nTipo == 2
				aDesc := { "V", nVlrDesc }
			EndIf

			lRet := LJProfile(11, @cAutorDesc, aDesc, nPerDesc, nVlrDesc,Nil,Nil,lCtrlB)

		ElseIf cFormDesc == "2"

			lRet := LJProfile(11, @cAutorDesc, aDesc, nPerDesc, nVlrDesc,Nil,Nil,lCtrlB)
    	EndIf

	Endif
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7CancIT ºAutor  ³ Vendas Clientes    º Data ³  05/08/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Possibilita o cancelamento do item ao pressionar a tecla    º±±
±±º          ³delete sobre o item do aCols                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³SIGALOJA - Venda Assistida Concomitante                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7CancIT()
Local lRet 			:= .F.					// Variaval que retorna status da exclusao do item
Local aArea			:= GetArea()
Local nIndSB0		:= 0			        // Para guardar o nr do indice atual SB0
Local nIndSB1		:= 0				    // Para guardar o nr do indice atual SB1
Local nIndSF4		:= 0					// Para guardar o nr do indice atual SF4
Local nIndSL1		:= 0					// Para guardar o nr do indice atual SL1
Local nIndSA1		:= 0					// Para guardar o nr do indice atual SA1
Local nRegSB0		:= 0 					// Para guardar o nr do registro no arq  SB0
Local nRegSB1		:= 0					// Para guardar o nr do registro no arq  SB1
Local nRegSF4		:= 0					// Para guardar o nr do registro no arq  SF4
Local nRegSL1		:= 0					// Para guardar o nr do registro no arq  SL1
Local nRegSA1		:= 0					// Para guardar o nr do registro no arq  SA1
Local cSup 			:= Space(15)
Local cQualItem 	:= ""
Local nCancItem		:= 0
Local nPosProd  	:= GdFieldPos("LR_PRODUTO")
Local nPosQuant 	:= GdFieldPos("LR_QUANT")
Local nPosDesU  	:= GdFieldPos("LR_VALDESC")
Local nPosTotIt 	:= GdFieldPos("LR_VLRITEM")
Local nPosTes		:= GdFieldPos("LR_TES", aHeaderDet)
Local nPosValIpi	:= GdFieldPos("LR_VALIPI", aHeaderDet)
Local cCodProd  	:= ""
Local cDescProd 	:= ""
Local cQuant		:= ""
Local cUnit	  		:= ""
Local cTotIt		:= ""
Local cDesconto 	:= ""
Local cElemen		:= ""
Local nPerRet		:= 0
Local iRetorno  	:= 0
Local cRet			:= " "
Local nFor			:= 1										// controle de loop
Local aSeqImp		:= {}
Local nItemCanc		:= 0
Local nItemImpr		:= 0
Local lMvDescISS	:= SuperGetMV("MV_DESCISS",,.F.)			// Indica se ha desconto do iss no financeiro
Local nMvAliqISS	:= SuperGetMV("MV_ALIQISS",,5)				// Aliquota do ISS
Local cMvCodBar		:= SuperGetMV("MV_CODBAR",,"S")				// Define se imprime o cod de barra no cupom fiscal
Local cMvTpSolCf	:= SuperGetMV("MV_TPSOLCF",,"S,F")			// Tipos de clientes que possuem icms solidario
Local aIcmsSol      := {}                                       // Aramzena nBaseRet, nValRet e nPerSol
Local nBaseRet      := 0                                        // Retorno da Base do ICMS Solidario
Local nValRet       := 0                                        // Retorno do Valor do ICMS Solidario
Local nPerSol       := 0                                        // Percentaual da aliquota do ICMS Solidario
Local nVlrIPI       := 0
Local nAliqRed		:= 0
Local aTamL2QUANT	:= TamSX3("L2_QUANT")						// Tamanho e decimal do campo L2_QUANT
Local aTamL2VrUnit  := TamSx3("L2_VRUNIT")						// Tamanho e decimal do campo L2_VRUNIT
Local aTamL2VlrItem	:= TamSx3("L2_VLRITEM")						// Tamanho e decimal do campo L2_VLRITEM
Local aLjExcecao	:= {}
Local lExcecaoFcl	:= .F.
Local LExecPE7017	:= .F.
Local lAutoExA		:= IsBlind()								// Verifica se a rotina sera executada via execauto ou nao
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica os itens que nao estao deletados para enviar o item correto para cancelamento  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
For nFor := 1 To Len(aCols)
	If !aCols[nFor][Len(aCols[nFor])]
		nItemImpr++
		Aadd(aSeqImp,{nFor,nItemImpr})
	Else
		Aadd(aSeqImp,{nFor,0})
	EndIf
Next nFor

nItemCanc := Ascan( aSeqImp, {|Z| Z[1] == N})
If aSeqImp[nItemCanc][2] == 0
	lRet := .T.
Else
    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//|Obtem qual item deverá ser cancelado no ECF 		    			 |
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nCancItem := aSeqImp[nItemCanc][1]
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica se é possivel cancelar todos ou só o ultimo item         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	iRetorno 	:= IfStatus(nHdlECF, "4", @cQualItem)
	If Upper(AllTrim(cQualItem))<>"TODOS"			//Posso cancelar qualquer item da impressora
		If nCancItem < Len(aSeqItem)
			If !lAutoExA
				MsgAlert( STR0041 ) //"Esta impressora só permite o cancelamento do último item, para cancelar o cupom fiscal, Cancele ou Salve o orçamento."
			Else
				ConOut( STR0041 ) //"Esta impressora só permite o cancelamento do último item, para cancelar o cupom fiscal, Cancele ou Salve o orçamento."
			EndIf
		EndIf
	EndIF

    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica o status do ECF                                     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	iRetorno := IFStatus(nHdlECF, "9", @cRet)
	If iRetorno <> 0
		lRet := .F.
	Else
	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Posiciona os arquivos                                        ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea("SB1")
		nIndSB1:=IndexOrd()
		nRegSB1:=Recno()
		DbSetOrder(1)
		SB1->( DbSeek( xFilial("SB1") + aCols[n][nPosProd]) )

		DbSelectArea("SB0")
		nIndSB0:=IndexOrd()
		nRegSB0:=Recno()
		DbSetOrder(1)
		SB0->( DbSeek( xFilial("SB0") + aCols[n][nPosProd]) )

		DbSelectArea("SF4")
		nIndSF4:=IndexOrd()
		nRegSF4:=Recno()
		DbSetOrder(1)
		SF4->( DbSeek( xFilial("SF4") + aColsDet[n][nPosTes] ) )

		aLjExcecao := MaFisRet(nCancItem,"IT_EXCECAO")
		lExcecaoFcl:= Len(aLjExcecao) > 0
		LjGrvLog( M->LQ_NUM , " TES " + AllTrim(SF4->F4_CODIGO) + " - Verificação de exceção fiscal ", aLjExcecao)

	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica a situacao tributaria do item                       ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If SF4->F4_ISS == "S" .AND. ( Lj7RecISS() .OR.  SA1->A1_RECISS <> "1" )
			cSitTrib := "S" + AllTrim (Str( IIF( SB1->B1_ALIQISS > 0, SB1->B1_ALIQISS, nMvAliqISS ),5,2 ) )

		ElseIf SF4->F4_MKPSOL<>"1" .And. ( SB1->B1_PICMRET > 0 .OR.;
		 		(lExcecaoFcl .AND. (aLjExcecao[3] > 0 .OR. aLjExcecao[16] > 0 )) );
				.AND. SA1->A1_TIPO $ cMvTpSolCf .AND. SF4->F4_BSICMST <> 100
				
			cSitTrib := "F"		//Substituicao tributaria (Icms Solidario)

		ElseIf (SF4->F4_BASEICM > 0 .AND. SF4->F4_BASEICM < 100) .Or. ;
			(lExcecaoFcl .AND. (aLjExcecao[14] > 0) .AND. (aLjExcecao[14] < 100))

			/*Aberto um ponto de entrada para que o cliente possa utilizar
			a aliquota de redução que cadastrou na tabela SL4 ao invés de
			utilizar a do SB0*/
			If ExistBlock("LJ7017") .AND. !lFtvdVer12
				LjGrvLog( M->LQ_NUM, " Antes do PE LJ7017")
				nAliqRed := ExecBlock("LJ7017",.F.,.F.)
				LjGrvLog( M->LQ_NUM, " Retorno do PE LJ7017", nAliqRed)
				LExecPE7017 := .T.
			Endif

			If ExistBlock("FTVD7017") .AND. lFtvdVer12
				LjGrvLog( M->LQ_NUM, " Antes do PE FTVD7017")
				nAliqRed := ExecBlock("FTVD7017",.F.,.F.)
				LjGrvLog( M->LQ_NUM, " Retorno do PE FTVD7017", nAliqRed)
				LExecPE7017 := .T.
			EndIf
			
			If !LExecPE7017 .Or.;
				(LExecPE7017 .And. ((Valtype(nAliqRed) <> "N") .OR. ((nAliqRed <= 0) .Or. (nAliqRed >= 100))))
				
				If LExecPE7017
					LjGrvLog( M->LQ_NUM, " Problema no Ponto de Entrada LJ7017 ou FTVD7017. " +CHR(10)+CHR(13)+;
									" Solução: o retorno do PE deve ser do tipo  Numerico ou o " +;
									" seu retorno não está entre 1 e 99"+CHR(10)+CHR(13)+;
									" Revise o Ponto de Entrada! " +CHR(10)+CHR(13)+;
									" Será efetuado a busca padrão nas tabelas SB0 e SF4", nAliqRed)
				EndIf				
				
				//a Exceção Fiscal será maior que qualquer outra regra 
				If lExcecaoFcl
					nAliqRed := SB0->B0_ALIQRED
					LjGrvLog( M->LQ_NUM, " Alíquota reduzida configurada como exceção fiscal [ se campo estiver zerado preencha a redução no campo B0_ALIQRED] " , nAliqRed)
				ElseIf lCenVenda
					nAliqRed := SF4->F4_BASEICM
					LjGrvLog( M->LQ_NUM, " Cenário de venda ativo e alíquota reduzida configurada [campo F4_BASEICM] ", nAliqRed)
				Else
					nAliqRed := SB0->B0_ALIQRED		// Considero a alíquota de redução do cadastro de produtos
					LjGrvLog( M->LQ_NUM, " Alíquota reduzida configurada pela TES [campo F4_BASEICM - se alíquota estiver zerada preencha a redução no campo B0_ALIQRED] " , nAliqRed)
				EndIf
			EndIf

			cSitTrib := "T" + AllTrim(Str(nAliqRed,5,2))		// Com redução de Icms na Base de Cálculo do Imposto

		ElseIf SF4->F4_LFICM == "I"								// Isento
			cSitTrib := "I"

		ElseIf SF4->F4_LFICM == "N"								// N„o sujeito a ICMS
			cSitTrib := "N"

		Else													// Com ICMS
			nAliquota := AliqIcms("N","S",SA1->A1_TIPO,"I")
			cSitTrib := "T" + AllTrim(Str(nAliquota,5,2))
		EndIf

	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta o codigo do produto                                   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cMvCodBar == "S"  .AND. !Empty(SB1->B1_CODBAR)
			cCodProd  := Substr(SB1->B1_CODBAR,1,13)
		Else
			cCodProd  := aCols[n][nPosProd]
		EndIF

	    //ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Ajusta as variaveis para enviar o comando de cancelamento    ³
		//³ para o ECF                                                   ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nPosValIpi > 0
		   nVlrIPI := aColsDet[n][nPosValIpi]
		EndIf

		cDescProd := SB1->B1_DESC
		cQuant    := StrZero(aCols[n][nPosQuant],aTamL2QUANT[1], aTamL2QUANT[2])
		cUnit     := Str((aCols[n][nPosTotIt]+ aCols[n][nPosDesU]+nVlrIPI)/aCols[n][nPosQuant],aTamL2VrUnit[1] ,nDecimais)
		cTotIt    := Str((aCols[n][nPosTotIt]+ aCols[n][nPosDesU]+nVlrIPI),aTamL2VlrItem[1] ,nDecimais)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Segundo a legislacao o cliente quando estiver configurado como solidario³
		//³A1_TIPO = 'S' deverá sempre ser tributado, independente da configuracao ³
		//³do TES.                                                                 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If (SA1->A1_TIPO $ cMvTpSolCf .OR. ( SA1->A1_TIPO == "S" )) .AND. (SF4->F4_INCSOL <> "N")
		    If SB1->B1_PICMRET > 0 .OR. SB1->B1_VLR_ICM > 0 .OR. !Empty( SB1->B1_GRTRIB )
			   nBaseRet := MaFisRet(1,"IT_BASESOL")
			   nValRet  := MaFisRet(1,"IT_VALSOL")
			   nPerSol  := MaFisRet(1,"IT_ALIQSOL")
			EndIf
			aIcmsSol := { nBaseRet ,nValRet ,nPerSol }
			cUnit    := Str(Val(cUnit) + (aIcmsSol[2]/Val(cQuant)),aTamL2VrUnit[1], aTamL2VrUnit[2] )
			cTotIt   := Str(Val(cUnit) * Val(cQuant),aTamL2VlrItem[1] ,nDecimais)
		EndIf

		cDesconto := Str(aCols[n][nPosDesU],8,2)

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Envia o comando de cancelamento para o ECF                             ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		iRetorno := IFCancItem(nHdlECF,Str(nCancItem,3),cCodProd,cDescProd,cQuant,cUnit,cDesconto,cSitTrib)
		If iRetorno == 0
			lRet := .T.
		Else
			lRet := .F.
		EndIf

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Retornando as posições originais do arquivo                     ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		DbSelectArea("SA1")
		If nIndSA1 > 0
			DbSetOrder(nIndSA1)
		EndIf
		If nRegSA1 > 0
			GoTo(nRegSA1)
		EndIF

		DbSelectArea("SB1")
		If nIndSB1 > 0
			DbSetOrder(nIndSB1)
		EndIf
		If nRegSB1 > 0
			GoTo(nRegSB1)
		EndIF

		DbSelectArea("SB0")
		If nIndSB0 > 0
			DbSetOrder(nIndSB0)
		EndIf
		If nRegSB0 > 0
			GoTo(nRegSB0)
		EndIF

		DbSelectArea("SF4")
		If nIndSF4 > 0
			DbSetOrder(nIndSF4)
		EndIf
		If nRegSF4 > 0
			GoTo(nRegSF4)
		EndIF

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Retornando à área original do arquivo                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Len(aArea) > 0
			RestArea(aArea)
		EndIf
	EndIf
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7DefTab ºAutor  ³ Vendas Clientes    º Data ³  22/10/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Funcao gerada para controlar a tabela em uso por linha.    º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºAplicacao ³ Funcao de uso generico                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7DefTab(lGravaTab,cCliente,cLoja,cNumOrcam)
Local cTabela     := cTabPad
Local nPosTabela  := aScan(aPosCpoDet, {|x| Trim(Upper(x[1])) == "LR_TABELA"})  // Posicao da tabela de precos.
Default lGravaTab := .F.

Default cCliente  := If(Type("M->LQ_CLIENTE") <> "U", M->LQ_CLIENTE	, "")
Default cLoja	  := If(Type("M->LQ_LOJA") 	  <> "U", M->LQ_LOJA	, "")
Default cNumOrcam := If(Type("M->LQ_NUM") 	  <> "U", M->LQ_NUM		, "")

If Len(aColsDet) >= n
	If !lGravaTab
		If !Empty(aColsDet[n][nPosTabela])
			cTabela := aColsDet[n][nPosTabela]
		Endif
	Else
		aColsDet[n][nPosTabela] := cTabPad
	Endif
Endif

Return cTabela

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjNFFimVd ºAutor  ³ Vendas Clientes    º Data ³  25/09/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Verifica se deve fazer a emissao da NF na Finalizacao da   º±±
±±º          ³ Venda Assistida.                                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpL1 - Verifica se deve inicializar a variavel estatica   º±±
±±º          ³         lEmiteNF.                                          º±±
±±º          ³ ExpL2 - Verifica se deve inicializar como impressao de     º±±
±±º          ³         Cupom Fiscal.                                      º±±
±±º          ³ ExpL3 - Verifica se eh Finalizacao da Venda                º±±
±±º          ³ ExpN6 - Referencia do ponto de entrada  LJ7087             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjNFFimVd( lCria	  , lEmiteCF	, lFinaliza , cA1Est ,;
				   	cA1Pessoa ,	nRefLJ7087	, lLJ7087	, nDocSai,;
					lPergTipo)

Local cEstCob		:= ""								//Estado da Empresa
Local lFisNota		:= SuperGetMV("MV_FISNOTA",,.F.)	//Utiliza emissao de NF
Local lLibEmiteNF	:= .F.								//Libera a emissao de NF
Local lRet			:= .F.
Local lAutoExA		:= IsBlind()						// Verifica se a rotina sera executada via execauto ou nao
Local cTitCupNfce	:= STR0046							//Cupom
Local nRetLJ7087	:= 0								//0 = Verifica emissao (padrão)  / 1 = Emissão de CF ou NFC-e / 2 = Emissao de nota
Local lUseSat		:= IIF(ExistFunc("LjUseSat"),LjUseSat(),.F.)	//Usa Sat
Local lMVLJLBNT		:= SuperGetMV("MV_LJLBNT",,0) > 0	//Habilita Finaliza Venda - Vide doc:http://tdn.totvs.com.br/display/PROT/TUXK67_DT_Disponibilizar_Emissao_Nota_Fiscal_Interestadual_Venda_Assistida
Local lEmitNfce		:= LjEmitNFCe() 
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default lCria		:= .F.								//Efetua as validacoes para emissao de NF
Default lEmiteCF	:= .F.								//Forca a emissao de Cupom Fiscal
Default lFinaliza	:= .F.								//Eh finalizacao da Venda
Default cA1Est		:= ""								//Estado do cliente
Default cA1Pessoa	:= ""								//Pessoa Juridica / Fisica
Default nRefLJ7087	:= 0								//Parametro para retorno por referencia do valor do P.E LJ7087
Default lLJ7087 	:= ExistBlock("LJ7087")				//verifica se o ponto de entrada LJ7087 está compilado
Default nDocSai		:= 1								//Tipo de Documento: 1 - Cupom Fiscal / 2 - Nota Fiscal
Default lPergTipo	:= .T.								//Define se perguntara o tipo do documento ou se considera o nDocSai recebido como parametro\Default. 

Static	lEmiteNF	:= .F.								//Permite a emissao de NF


LjGrvLog( SL1->L1_NUM, "Atualiza a variavel lEmiteNF (lCria)? ", lCria )
LjGrvLog( SL1->L1_NUM, "Chamado por: ", ProcName(1) + "(" + cValToChar(ProcLine(1)) + ")" )

If !lMvLjPDVPa .AND. !lFtvdVer12
	
	LjGrvLog( SL1->L1_NUM, "PE LJ7087 compilado: ", lLJ7087 )
	If lCria .AND. lLJ7087

		nRetLJ7087 := ExecBlock( "LJ7087", .F., .F.)
		LjGrvLog( SL1->L1_NUM, "Retorno do PE LJ7087: ", nRetLJ7087 )

		nRefLJ7087 := nRetLJ7087 //Guarda valor do p.e para retorno por referencia
		
		If ValType(nRetLJ7087) == "N"
			If nRetLJ7087 == 1 //1 = Emissão de CF ou NFC-e
				lEmiteNF := .F.
				lCria	 := .F.
			ElseIf nRetLJ7087 == 2 //2 = Emissao de nota
				lEmiteNF := .T.
				lCria	 := .F.
			EndIf
		EndIf
	EndIf

	If lCria .AND. cPaisLoc == "BRA"
		If lFisNota .AND. !lEmiteCF
			cEstCob := SM0->M0_ESTCOB
			LjGrvLog( SL1->L1_NUM, "Estado de Cobrança (M0_ESTCOB): ", cEstCob )
			If !Empty(cEstCob)
				Do Case
			    	Case cEstCob == "SP"
						//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
						//³Para  SP valida por hard-code por enquanto³
						//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
						If LjCanUseNF( SM0->M0_CGC )
							//Verifica quais sao as regras de validacao para emissao da NF no varejo
							lEmiteNF := Lj950RegraNF(SM0->M0_CGC, @lLibEmiteNF)
							LjGrvLog( SL1->L1_NUM, "SP - Lj950RegraNF (lEmiteNF): ", lEmiteNF )
						Else
							//Se PAF-ECF, nao permite emissao de NF
							If LjNFPAFECF(SM0->M0_CGC)
								lEmiteNF := .F.
								LjGrvLog( SL1->L1_NUM, "SP - PAF-ECF (Nao permite emissao de NF)")
							
							//verifica se permite venda interestadual
							Else								
								//Caso Falso verifica se a venda eh interestadual
								lEmiteNF := LjNfInterEst(SM0->M0_CGC , cA1Est , cA1Pessoa)
								LjGrvLog( SL1->L1_NUM, "SP - NF InterEstadual (lEmiteNF): ", lEmiteNF )
							EndIf
						Endif
					Otherwise
						/*
							Para as outras UF, somente verifica quais sao as regras de validacao para emissao da NF no varejo
						*/
						lEmiteNF := Lj950RegraNF(SM0->M0_CGC, @lLibEmiteNF)
						LjGrvLog( SL1->L1_NUM, "Lj950RegraNF (lEmiteNF): ", lEmiteNF )
				EndCase

				If NMODULO == 5
					If lFinaliza .OR. (!lFiscal .AND. LjEmiteNF(SM0->M0_CGC,lLibEmiteNF))
						nDocSai := 2
					EndIf
				Else
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Verificar se nao Emite NF caso o modulo que esta utilizando a funcao nao seja o SIGAFAT ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					If lEmiteNF
						If lFinaliza .OR. (!lFiscal .AND. LjEmiteNF(SM0->M0_CGC,lLibEmiteNF) .And. !lEmitNfce .And. !lIsPafNfce)
							If nDocSai == 1
								lEmiteNF := .F.
								LjGrvLog( SL1->L1_NUM, "Emite NFC-e ou SAT CF-e (Nao permite emissao de NF)")
							EndIf
						Else
							LjGrvLog( SL1->L1_NUM, "Estado com Obrigatoriedade com PAF-ECF? (Nao permite fazer a pergunta) ", LJAnalisaLeg(64)[1] )
							LjGrvLog( SL1->L1_NUM, "Venda Interestadual habilitada? (MV_LJLBNT) ", lMVLJLBNT )
							// Estados com obrigacao de PAF-ECF nao tem a pergunta:
							// "Documento Fiscal de Saida"##"Qual Documento Fiscal de Saida sera impresso na venda?"##"Cupom"##"Nota"
							If lMVLJLBNT .OR. lEmitNFCe .OR. lUseSAT .OR. !LJAnalisaLeg(64)[1]
								//"Documento Fiscal de Saida"##"Qual Documento Fiscal de Saida sera impresso na venda?"##"Cupom"##"Nota"
								If (lEmitNfce .And. !lUseSat) .Or. lIsPafNfce
									cTitCupNfce := "N&FC-e"
								ElseIf lUseSat
									cTitCupNfce := IIF(lMFE, "MF-e", "SAT")
								EndIf
								If lPergTipo 									
									nDocSai := IIF( lAutoExA, 0, Aviso(STR0044,STR0045,{cTitCupNfce, STR0047}) )

									// Avalia se houve troca de regime de doc de saida para ajustar a MatxFis
									If 'LQ_CLIENTE' $ ReadVar() // Tela de aviso disparada do campo cliente do venda assistida
										If MaFisFound('NF')								 
											If nDocSai == 1 .AND. cTitCupNfce == 'SAT'   // Escolha do regime SAT
												MaFisAlt("NF_SERSAT",LJGetStation("SERSAT"))
											Else
												MaFisAlt("NF_SERSAT", Space(Len(SL1->L1_SERSAT)))  // estacao SAT mas ira emitir NF, nao seta SAT na Matxfis	
											Endif
										Endif
									Endif
								Endif 
								If nDocSai == 1
									lEmiteNF := .F.
									LjGrvLog( SL1->L1_NUM, "Nao foi escolhido a opcao Nota Fiscal: ", nDocSai )
								EndIf
							Else
								nDocSai := 1
								lEmiteNF := .F.
								LjGrvLog( SL1->L1_NUM, "MV_LJLBNT=.F. E NAO NFC-e/SAT E UF com PAF obrigatorio (lEmiteNF)", lEmiteNF)
							Endif
						EndIf

						//atribui a resposta da pergunta feito acima (Cupom/NFC-e/SAT ou Nota Fiscal)
						LjVassConc(nDocSai)
				    Else
				    	// se nao permitiu emissao de NF
				    	nDocSai := 1	//1-Cupom Fiscal
				    	LjVassConc(nDocSai)
				    EndIf
				EndIf
			Else
				nDocSai := 1	//1-Cupom Fiscal
				lEmiteNF := .F.
				LjVassConc(nDocSai)
				LjGrvLog( SL1->L1_NUM, "Estado de Cobranca nao preenchido (Nao permite emissao de NF)" )
			EndIf
		Else
			nDocSai := 1	//1-Cupom Fiscal
			lEmiteNF := .F.
			LjVassConc(nDocSai)
			LjGrvLog( SL1->L1_NUM, "Verifica se é concomitante (Nao permite emissao de NF)" )
		EndIf
		lRet := lEmiteNF
	Else
		lRet := lEmiteNF
	EndIf
ElseIf lFtvdVer12
	lEmiteNF := .T.
	lRet     := lEmiteNF
Else
	lEmiteNF:= .F.
	lRet	:= lEmiteNF
EndIf

LjGrvLog( SL1->L1_NUM, "Retorno lRet(lEmiteNF): ", lRet)

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjVassConcºAutor  ³ Vendas Clientes    º Data ³  24/09/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Indica se utiliza Impressao do Cupom Fiscal Concomitante.  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpN1 - Determina qual o tipo do documento da Venda.       º±±
±±º          ³     0 - Apenas retorna a variavel estatica lImpConc        º±±
±±º          ³     1 - Altera o Tipo de Impressao para Cupom Fiscal       º±±
±±º          ³     2 - Altera o Tipo de Impressao para Nota Fiscal        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Loja701                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjVassConc(nTipoDoc)
Local lVassConc	:= .F.			//Utiliza Venda Concomitante
Local cCNPJ		:= SM0->M0_CGC  //Cnpj da Loja
Local lEmitNfce	:= LjEmitNFCe() 
Local lFtvdVer12:= LjFTVD()		//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default nTipoDoc	:= 0					//Tipo de documento para emissao

Static	lImpConc	:= .F.					//Determina se deve efetuar a impressao Concomitante

If nTipoDoc <> 0
	cLQCliente := ""						//Reinicializa o cliente
	cLQProvEnt := ""

	//³Verifica se eh usuario Fiscal.³
	If lFiscal
		If !lEmitNfce
			//Verifica se e necessario verificar o CNPJ para nao concomitancia
			If LJAnalisaLeg(32)[1] .Or. lMvljpdvpa
				If LjNVCC(cCNPJ)
					If !lFtvdVer12
						lVassConc := SuperGetMV("MV_LJVACC",,.F.)
					ElseIf lFtvdVer12
						lVassConc := .F.
					EndIf
				Else
					lVassConc := .T.
				EndIf
			Else
				lVassConc := SuperGetMV("MV_LJVACC",,.F.)
			EndIf
		EndIf
	EndIf

	If lVassConc .AND. LjConcNota()
		If nTipoDoc == 1		//Cupom Fiscal
			lVassConc := .T.
		ElseIf nTipoDoc == 2	//Nota Fiscal
			lVassConc := .F.
		EndIf
	EndIf
	lImpConc := lVassConc
EndIf

Return lImpConc

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjConcNota ºAutor  ³ Vendas Clientes         º Data ³ 14/09/07 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Verificar se a empresa logada utiliza ECF concomitante e      º±±
±±º          ³ possui autorizacao para emitir nota                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ .T. - filial pode utilizar ECF concomitante e nota            º±±
±±º          ³ .F. - filial nao pode utilizar                                º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjConcNota()
Local lFisNota	:= SuperGetMV("MV_FISNOTA",,.F.)	// Verifica se esta configurado para emissao de NF
Local lLjvacc	:= SuperGetMV("MV_LJVACC",, .F.)	// Verifica se esta configurado para impressao concomitante
Local lRet		:= .F. 								// Retorno da funcao

If LjNfPafEcf(SM0->M0_CGC)
	If lFisNota .AND. lFiscal .AND. lLjvacc
		lRet := .T.
    EndIf
Else
	If lFisNota .AND. lFiscal
		lRet := .T.
	EndIf
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³GetFretAlt ºAutor  ³ Vendas Clientes         º Data ³ 02/02/09 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Retorna a variavel logica (static) lFreteAlt				     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Logico											             º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function GetFretAlt()
Return lFreteAlt

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³SetFretAlt ºAutor  ³ Vendas Clientes         º Data ³ 02/02/09 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Atribui valor a variavel logica (static) lFreteAlt			 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ 													             º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function SetFretAlt(lAlterado)
	lFreteAlt := lAlterado
Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj701ValDesºAutor  ³ Vendas Clientes         º Data ³          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³                                                               º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ 													             º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj701ValDes(nVlrMerc , nValDescV, nPerVal, oDesconto )

Local nX 			:= 0
Local nPosPrcTab	:= Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB"})				// Posicao do Preco de Tabela
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]	// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]	// Posicao do Valor unitario do item
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do valor de desconto
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]	// Posicao do Valor do item
Local nValorItem	:= 0																		// Valor do item que sera utilizado no calculo do desconto se MV_LJTPDES = 1
Local nVlUnit		:= 0
Local nVlrDesc		:= 0

Default nVlrMerc 	:= 0
Default nValDescV 	:= 0
Default nPerVal		:= 0

For nX := 1 To Len(aCols)
	If !Atail( aColsDet[nX] )	//verifica se a linha esta deletada
		If !lCenVenda .AND. &( "SB0->B0_PRV" + Lj7DefTab() ) == 0
			nValorItem := IIf(cPaisLoc <> "ARG", aCols[nX][nPosVlUnit], aColsDet[nX][nPosPrcTab])
		Else
			nValorItem := aColsDet[nX][nPosPrcTab]
		Endif

		nVlUnit	 :=  oDesconto:DescontoValor( nValorItem, aCols[nX][nPosQuant], aCols[nX][nPosValDesc] )
		nVlrDesc += ( nPerVal * (nVlUnit / 100 ) ) * aCols[nX][nPosQuant]
	EndIf
Next nX

nVlrDesc := Round( nVlrDesc , nDecimais )

Return nVlrDesc

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7SetDescAºAutor  ³ Vendas Clientes         º Data ³ 02/02/09 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Atribui valor a variavel logica (static) nDescAnt			 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ 													             º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7SetDescAnt( nValor )
nDescAnt := nValor
Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7GetDescAnt ºAutor  ³ Vendas Clientes      º Data ³ 02/02/09 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDescricao ³ Retorna o valor da variavel logica (static) nDescAnt			 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ 													             º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7GetDescAnt()
Return nDescAnt

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7RegDescºAutor  ³Vendas CRM          º Data ³  30/10/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Calcula o valor do item, aplicando descontos da regra de    º±±
±±º          ³descontos, quando houver regras cadastradas.                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Codigo do produto digitado                          º±±
±±º          ³ExpL2 - Indica se utiliza venda concomitante                º±±
±±º          ³ExpA3 - aCols da Venda assistida                            º±±
±±º          ³ExpA4 - aHeader da Venda assistida                          º±±
±±º          ³ExpN5 - Quantidade vendida                                  º±±
±±º          ³ExpL6 - Indica se eh um produto bonificado                  º±±
±±º          ³ExpL7 - Indica se houve desconto no total pela reg. de desc.º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function Lj7RegDesc(	cProduto	, lVAssConc	, aCols		, aHeader		,;
							nQuant		, lBonus	, lDescCab	, lScCsPreco	,;
							nKit		)
Local lRet		:= .T.
Local nTotal	:= 0
Local nPValDsc	:= aScan(aHeader,{|x|AllTrim(x[2]) == "LR_VALDESC" })
Local nPDelet	:= Len(aHeader)+1
Local nValDscIt	:= 0
Local bSomaDsc	:= { |x| nValDscIt += If(x[nPDelet],0,x[nPValDsc])}
Local lDescRegr	:= .F.
Local nPosCodReg:= Ascan(aHeaderDet,{|x|AllTrim(x[2])=="LR_CODREG"})		// Posicao do campo do codigo da Regra de desconto
Local nPosVlDesR:= Ascan(aHeaderDet,{|x|AllTrim(x[2])=="LR_VLDESRE"})		// Posicao do campo do valor consedido pela regra de desconto
Local cCodRegDe := ""														// Codigo da Regra de desconto usada
Local nVlDesReg := 0														// Valor de desconto consedido pela regra de desconto

Default lDescCab	:= .F.
Default lScCsPreco	:= .F.													// Indica se a consulta de preco via WS esta habilitada
Default nKit		:= 0													//Quando cenario de venda e kit com desconto

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Calcula o valor do item 									 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lVAssConc .And. lCenVenda

	lDescRegr := LjDescItem(cProduto  , M->LQ_CLIENTE	, M->LQ_LOJA, nQuant,;
							@cCodRegDe, @nVlDesReg )

	lRet := Lj7VlItem(Nil,lDescRegr,lBonus)

	If lRet
		aEval( aCols, bSomaDsc )
		nTotal		:= Lj7T_Subtotal(2) + Lj7T_DescV(2) + nValDscIt
		lDescCab    := LjDescCab(	cProduto, M->LQ_CLIENTE	, M->LQ_LOJA	, @aCols	,;
					             	@aHeader, nTotal		)

		If nPosCodReg > 0
			aColsDet[n][nPosCodReg] := cCodRegDe
		EndIf

		If nPosVlDesR > 0
			aColsDet[n][nPosVlDesR] := nVlDesReg
		EndIf
	EndIf
Else

	If lCenVenda //Faz essa chamada somente para consulta da existência da regra de desconto
		lDescCab := LjDescCab(	cProduto, M->LQ_CLIENTE	, M->LQ_LOJA , @aCols,;
								@aHeader, nTotal		, .T.)
	EndIf
	
	lRet := Lj7VlItem(	Nil,lDescRegr	,lBonus	,Nil,;
						Nil,Nil			,Nil	,Nil,;
						Nil,lScCsPreco	,nKit	,Nil,;
						Nil,Nil			,Nil	,lDescCab)

	If lRet
		If lCenVenda .OR. lScCsPreco
			lDescRegr := LjDescItem(cProduto	, M->LQ_CLIENTE	, M->LQ_LOJA, nQuant,;
									@cCodRegDe	, @nVlDesReg	, lScCsPreco)

			aEval( aCols, bSomaDsc )
			nTotal	:= Lj7T_Subtotal(2) + Lj7T_DescV(2) + nValDscIt
			If lCenVenda
				lDescCab := LjDescCab(	cProduto, M->LQ_CLIENTE	, M->LQ_LOJA , @aCols,;
										@aHeader, nTotal		, .F.)
			EndIf

			If nPosCodReg > 0
				aColsDet[n][nPosCodReg] := cCodRegDe
			EndIf

			If nPosVlDesR > 0
				aColsDet[n][nPosVlDesR] := nVlDesReg
			EndIf
		EndIf
	EndIf

EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7GetMot ºAutor  ³Vendas CRM          º Data ³  30/10/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Calcula o valor do item, aplicando descontos da regra de    º±±
±±º          ³descontos, quando houver regras cadastradas.                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Codigo do produto digitado                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function  Lj7GetMot()

Local oBk := Nil

oBk := oMotivoDes

Return oBk

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7SetMot ºAutor  ³Vendas CRM          º Data ³  30/10/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Calcula o valor do item, aplicando descontos da regra de    º±±
±±º          ³descontos, quando houver regras cadastradas.                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Codigo do produto digitado                          º±±
±±º          ³ExpL2 - Indica se utiliza venda concomitante                º±±
±±º          ³ExpA3 - aCols da Venda assistida                            º±±
±±º          ³ExpA4 - aHeader da Venda assistida                          º±±
±±º          ³ExpN5 - Quantidade vendida                                  º±±
±±º          ³ExpL6 - Indica se eh um produto bonificado                  º±±
±±º          ³ExpL7 - Indica se houve desconto no total pela reg. de desc.º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7SetMot(oBk)

	oMotivoDes:= oBk

Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7Mv_DescºAutor  ³Vendas CRM          º Data ³  30/10/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se pede desconto                                   º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³LOJA701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Mv_Desc()

Local aAreMt 	:= GetArea()
Local lRet 		:= .F.
Local lUsaMotDes:= SuperGetMv("MV_LJUSAMD",,.T.)     //Valida se utiliza o motivo de desconto

If lUsaMotDes .AND. AliasIndic("MDU") .AND. AliasIndic("MDT")
	DbSelectArea('MDT')
	lRet := !MDT->(Eof())
	RestArea(aAreMt)
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7ValProvºAutor  ³ Vendas Clientes    º Data ³  22/11/10   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a validacao do campo da provincia de entrega            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Lj7ValProv()												  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ValProv()
Local lRet			:= .T.
Local nPosProvEnt	:= Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PROVENT"})
Local nX			:= 0

If cPaisLoc == "ARG"
	If SLQ->( ColumnPos("LQ_PROVENT") > 0 )
		If cLQProvEnt <> M->LQ_PROVENT
			For nX := 1 To Len(aCols)
				If !aCols[nX][Len(aCols[nX])]
					If SLR->( ColumnPos("LR_PROVENT") > 0 ) .AND. nPosProvEnt > 0
						nPosProvEnt	:= aPosCpo[nPosProvEnt][2]
						aCols[nX][nPosProvEnt] := M->LQ_PROVENT
						MaFisAlt("IT_PROVENT", aCols[nX][nPosProvEnt], nX)
						Lj7RecalImp(nX,1)
					EndIf
				EndIf
			Next nX
			oGetVA:Refresh()
		EndIf
	EndIf
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7FinalNFºAutor  ³ Vendas Clientes    º Data ³  08/02/11   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a limpeza da variavel lEmiteNF para a proxima venda     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Lj7FinalNF()												  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7FinalNF()

lEmiteNF := .F.

Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7RestCliºAutor  ³ Vendas Clientes    º Data ³  08/02/12   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Valida se o cliente pode ser alterado					      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Lj7TrocCli()												  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7TrocCli( lAutoExA , cLLQCliente, nTamLQCliente )
Local cMensagem	:=	STR0054  //Mensagem	//STR0054	//"Para as configurações de Venda e autorização para emissão de Nota Fiscal por AIDF, não será permitida a alteração do Cliente, após  a inclusão de produtos na venda."
Local cMV_CLIPAD:=	SuperGetMV("MV_CLIPAD")			// Cliente Padrao
Local nPosProd	:=	0
Local lRet		:=	.F.
Local lLjvAcc	:=	SuperGetMV("MV_LJVACC",,.F.)		// Verifica se esta configurado para impressao concomitante

Default lAutoExA	:= .F.
Default cLLQCliente	:= cMV_CLIPAD

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se o operador pode alterar o cliente, devido as regras³
//³do cenario de vendas ou por emitir nota em venda concomitante  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cPaisLoc == "BRA" .AND. ((LjConcNota() .OR. !lFiscal) .AND. lLjvAcc)
	If Len(aCols) > 0
		nPosProd := Ascan( aHeader, { |x| AllTrim(x[2]) == "LR_PRODUTO" } )
		If nPosProd > 0
			If !Empty(aCols[1][nPosProd])
				If !lAutoExA
					//"Atenção" # //"OK"
					Aviso(	STR0004, cMensagem,	{STR0003})	
				Else
					ConOut(cMensagem)
				EndIf

				If "LQ_CLIENTE" $ ReadVar()
					M->LQ_CLIENTE := SUBS(cLLQCliente, 1, nTamLQCliente)
				EndIf

				lRet := .T.
			EndIf
		EndIf
	EndIf
EndIf

IF !lRet
	M->LQ_RECISS := SA1->A1_RECISS
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjNDesGEºAutor  ³ Vendas Clientes    º Data ³  03/01/13     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Valida o desconto para produtos GE                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³LjNDesGE()												  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjNDesGE()

Local lLjNDesGE 	:= SuperGetMV("MV_LJDESGE",,.T.) // Parâmetro para bloquear desconto em produto do tipo GE
Local aAreB1 		:= {} // Area SB1
Local lGE			:= FindFunction("LjUP104OK") .AND. LjUP104OK() // Valida implementação da Garantia Estendida
Local lSFinanc      := AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)// Valida implementação do servico financeiro
Local aArea	   		:= {} // Area atual
Local lRet			:= .T. // Retorno
Local nPosProd 		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]// Posicao da codigo do produto
Local cProdAtu		:= aCols[n][nPosProd] // Posição do Produto

If lGE .AND. !lLjNDesGE
	aArea			:=  GetArea() // Armazena area atual
	aAreB1			:=  GetArea ("SB1") // Armazena area SB1
	DbSelectArea("SB1")
	DbSetOrder(1) // B1_FILIAL+B1_COD
	If DbSeek ( xFilial ("SB1")+cProdAtu)
		If Rtrim(SB1->B1_TIPO) == SuperGetMV("MV_LJTPGAR",,"GE")
			MsgAlert (STR0090) // Desconto não permitido para produtos do tipo Garantia Estendida
			lRet 	:= .F.
		EndIf
	EndIf
	RestArea(aAreB1) // Restaura a Area SB1
	RestArea(aArea)	// Restaura area anterior

EndIf

If lSFinanc
	aArea			:=  GetArea() // Armazena area atual
	aAreB1			:=  GetArea ("SB1") // Armazena area SB1
	DbSelectArea("SB1")
	DbSetOrder(1) // B1_FILIAL+B1_COD
	If DbSeek ( xFilial ("SB1")+cProdAtu) .AND. SB1->B1_TIPO == SuperGetMV("MV_LJTPSF",,"SF")
		MsgAlert (STR0110) //#"Desconto não permitido para produtos do tipo Serviço Financeiro"
		lRet 	:= .F.
	EndIf

	RestArea(aAreB1) // Restaura a Area SB1
	RestArea(aArea)	// Restaura area anterior
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjVldNDesc³ Vendas Clientes    º Data ³  02/025/13          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Valida o desconto na novas regra de Des. Varejo             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³LjVldNDesc()												  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjVldNDesc()
Local lRet			:= .T.
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]	// Posicao da Quantidade
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]// Posicao da codigo do produto
Local lVAssConc	 	:= LjVassConc()																			// Indica se o cliente utiliza a Vda Assistida Concomitante
Local lDescCab     	 := .F.															   							// Indica se houve desconto no total pela regra de desconto cenario de venda
Local nPosCodReg  	:= Ascan(aHeaderDet,{|x|AllTrim(x[2])=="LR_CODREG"})	    // Posicao do campo do codigo da Regra de desconto
Local nPosVlDesR  	:= Ascan(aHeaderDet,{|x|AllTrim(x[2])=="LR_VLDESRE"})     // Posicao do campo do valor consedido pela regra de desconto
Local nPosValDesc  	:= Ascan(aHeader,{|x|AllTrim(x[2])=="LR_VALDESC"})	    // Posicao do campo do codigo da Regra de desconto
Local nPosDesc  		:= Ascan(aHeader,{|x|AllTrim(x[2])=="LR_DESC"})     // Posicao do campo do valor consedido pela regra de desconto
Local lECommerce := SuperGetMV("MV_LJECOMM",,.F.) .AND.  ( SL1->((ColumnPos("L1_ECFLAG") > 0) .AND. (L1_ECFLAG == "1"))  .OR. (ExistFunc("LJ862ECAuto") .And. LJ862ECAuto()) )
Local lLjrgdes 	:=SuperGetMv("MV_LJRGDES",,.F.)  // Verifica se a Regra de Desconto Varejo está ativada

If !lEcommerce
	If lLjrgdes
		If nPosCodReg > 0
			aColsDet[n][nPosCodReg] := ""
		EndIf

		If nPosVlDesR > 0
			aColsDet[n][nPosVlDesR] := 0
		EndIf

		If nPosValDesc > 0
			aCols[n][nPosValDesc]	:= 0
		Endif

		If nPosDesc > 0
			aCols[n][nPosDesc] 		:= 0
		EndIf

		lRet := Lj7RegDesc(	aCols[n][nPosProd], lVAssConc	, @aCols	, @aHeader	,;
								aCols[n][nPosQuant]	, 	, @lDescCab)

	Else
		lRet := Lj7VlItem(5)

		If lRet
			aCols[n][nPosValDesc] := 0
			aCols[n][nPosDesc] 	 := 0
		EndIf
	EndIf
EndIf

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  |LjBxTpFret	º Vendas & DL		º Data ³  07/08/13        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Como o campo LQ_TPFRET, possui na sua estrutura o campo	  º±±
±±º			 |X3_BOX com os valores C e F,e no fonte,o campo possui 1 e 2.º±±
±±º			 |Eh necessario verificar qual o inicializador padrao, para seº±±
±±º			 |determinar as opcoes disponiveis.							  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   |LjBxTpFret( cIniPadrao )									  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ExpC1 = Inicializador Padrao								  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno	 ³ ExpC2 = Opcoes da Box									  º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LjBxTpFret( cIniPadrao )

Local cSX3Box 		:= ""
Default cIniPadrao	:= ""

//se o Inicializador Padrao for vazio ou possuir um numero, utilizamos os valores "1" ou "2"
If Empty(cIniPadrao) .OR. IsDigit(cIniPadrao)
	cSX3Box := "0=Sem Frete;1=CIF;2=FOB"
//senao, utilizamos os valores "C" ou "F" conforme o campo X3_BOX
Else
	cSX3Box := "S=Sem Frete;C=CIF;F=FOB"
EndIf

Return cSX3Box

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  |Lj7RecIss	º Vendas & DL	  	      Data ³  13/09/13        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Funcao que verifica e retorna o recolhimento de ISS pelo    º±±
±±º			 |cliente ou empresa. Apesar do cliente estar configurado comoº±±
±±º			 |recolhe ISS, a venda pode ocorrer em um municipio onde      º±±
±±º			 |o recolhimeento é realizado pela loja         			  º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7RecIss()
Local lCliRecIss := .F.
Local lMvDescISS	:= SuperGetMV("MV_DESCISS",,.F.)			// Indica se ha desconto do iss no financeiro
Local lAutoExA		:= IsBlind()																	// Verifica se a rotina sera executada via execauto ou nao

// verificacao padrao utilizado antes da implementacao do novo metodo
lCliRecIss	:=	SA1->A1_RECISS == "1" .AND. lMvDescISS

// Verifica se esta usando a nova configuracao para confirmar se o cliente recolhera o iss.
If lLjMVRecIss .AND. !isInCallStack('LJ110Grava')
	If lAutoExA .OR. nModulo == 23
		If	SL1->L1_RECISS == '1'
			lCliRecIss	:=	.T.
		Else
			lCliRecIss	:=	.F.  // se estiver em Branco ou valor 2 , cliente nao recolhe ISS
		EndIf
	Else
		If	M->LQ_RECISS == '1'
			lCliRecIss	:=	.T.
		Else
			lCliRecIss	:=	.F.  // se estiver em Branco ou valor 2 , cliente nao recolhe ISS
		EndIf
	EndIf
EndIf
Return lCliRecIss

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7VldMarg ³ Vendas Clientes    º Data ³  09/08/13          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Valida o desconto no total da venda                         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³LjVldNDesc()												  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³                                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function LJ7VldMarg(nVlrDesc)
Local lRet      := .T.
Local nI        := 1
Local nPosVlUnit:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]	// Posicao do Valor unitario do item
Local  nVlItem  := 0
Local nItem     := 0
For nI:= 1 To Len(aCols)
	//Efetua o rateio do desconto caso exista desconto no total da venda
	If !aCols[nI][Len(aCols[nI])]
		nVlItem:= nVlrDesc/Lj7T_Total(2)*100
		nVlItem:= ( aCols[nI][nPosVlUnit]*nVlItem ) /100
		nItem++
		If Lj701MgV(nI,,nVlItem,,nVlrDesc)
			If MsgYesNo(STR0095)//"Um(s) do(s) produto(s) esta fora da margem de preço cadastrada. Deseja continuar ?"
				If !LjProfile(35)
					Return .F.
				Else
					Exit
				EndIf
			Else
				Return .F.
			EndIf
		EndIf
	EndIf
Next nI

Return lRet



/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |LjKitProd	º Vendas        		º Data ³  05/09/2013      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Carga automatica de produtos configurado atraves do kit     º±±
±±º			 |de produto mestre.                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ ³ ExpA1 = aCols								              º±±
±±º            ³ ExpN2 = nItem					                    	  º±±
±±º            ³ ExpC3 =cProduto                                          º±±
±±º                                                                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno	 ³ aCols 													  º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function LjKitProd(aCols,nItem,cProduto,nQtdKit)

Local aArea			:= GetArea()// Gurada area
Local nDesconto		:= 0		// Caso o desconto esteja preenchida no cabecalho, esta variavel sera alimentada.
Local lRet          := .F.      // Autoriza a carregar todos os produtos que pertecem ao kit
Local aColsAux      := aClone(aCols[n]) //Armazena a copia do aCols que sera usado como referencia para incluir um novo registro no acols
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]			// Posicao da codigo do produto
Local nPosDescri	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESCRI"})][2]			// Posicao da descricao do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]				// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]				// Posicao do Valor unitario do item
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]			// Posicao do Valor do item
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]				// Posicao do percentual de desconto
Local nPosValDesc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]			// Posicao do valor de desconto
Local nValor        := 0  // Armazena o preco do produto
Local nValorDesc    := 0  // Armazena o valor do desconto do produto
Local nSubTotal     := 0  // Armazena o valor do produto - desconto x quantidade de produtos
Local nVlUnit       := 0  // Armazena o valor total unitario dos produtos
Local nPosKit       := Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_KIT"})			    	// Posicao do campo que indica se o item eh kit
Local cItOri        := AllTrim(Str(Len(aCols)))
Local nBkpLinha		:= 0
Local lContinua		:= .T.
Local cChaveMEV		:= "" 
Default aCols  		:= {}
Default nItem  		:= 0
Default cProduto  	:= ""
Default nQtdKit		:= 1

nBkpLinha := n
nItem := len(aCols)

DbSelectArea("MEU")
MEU->(DbSetOrder(1)) // MEU_FILIAL+MEU_CODIGO
If MEU->(DbSeek(xFilial("MEU") + PadR(AllTrim(cProduto),TamSX3("MEU_CODIGO")[1])))
	If !Empty(MEU->MEU_DESCNT) // Caso o desconto esteja preenchido no cabecalho, esse desconto sera utilizado.
		nDesconto := MEU->MEU_DESCNT
	EndIf
EndIf

DbSelectArea("MEV")
MEV->(DbSetOrder(1)) //MEV_FILIAL+MEV_CODKIT+MEV_PRODUT
cChaveMEV := xFilial("MEV") + PadR(cProduto,TamSX3("MEV_CODKIT")[1])

If MEV->(DbSeek(cChaveMEV))
	While !MEV->(Eof()) .AND. (MEV->MEV_FILIAL + MEV->MEV_CODKIT == cChaveMEV) 
		aCols[n][nPosProd]   := MEV->MEV_PRODUT
		aCols[n][nPosDescri] := Posicione('SB1',1,cChaveMEV,'SB1->B1_DESC')
		aCols[n][nPosQuant]  := Iif(nQtdKit > 0, nQtdKit * MEV->MEV_QTD, MEV->MEV_QTD)
		aCols[n][nPosVlUnit] := SB1->B1_PRV1
		
		//Proteção para se não for criado o campo LR_KIT
		If nPosKit > 0 
			aCols[n][nPosKit] := AllTrim(MEV->MEV_CODKIT)
		EndIf

		//Seta um array com os itens de cada Kit
		If ExistFunc("Lj7SetKit")
			Lj7SetKit(nItem, aColsAux[1], AllTrim(aCols[n][nPosProd]), AllTrim(MEV->MEV_CODKIT),cItOri)
		EndIf
				
		If nDesconto <> 0
			aCols[n][nPosDesc] := nDesconto
		Else
			aCols[n][nPosDesc] := MEV->MEV_DESCNT
			If MEV->MEV_DESCNT == 0
				aCols[n][nPosValDesc] := MEV->MEV_DESCNT
			EndIf
		Endif

	 	If !Lj7Prod(,,,,,1,AllTrim(MEV->MEV_PRODUT),nItem)//o 1 significa que não deve executar a chamada da LjKitProd novamente
	    	aCols[n][Len(aCols[n])] := .T.	  //Produto com restricao de cadastro e deve ser deletado
			lContinua := .F.
			Exit
    	Endif

    	MEV->(DbSkip())

	     If (MEV->MEV_FILIAL + MEV->MEV_CODKIT == cChaveMEV)
			aColsAux    := aClone(aCols[n])//registro modelo para incluir mais um registro
			nItem = Len(aCols) + 1   //incrementa o contador
			aColsAux[1] := padl(AllTrim(str(nItem)),2,"0") //atualiza o item sequencial do registro
			AAdd(aCols,aColsAux) //adiciona um novo registro
			n:= nItem //atualiza a posicao do registro
		Endif
	EndDo

	If lContinua
		n := nBkpLinha
		
		// Tratamento para não duplicar o código dos produtos do Kit na tela do Venda Assistida
		If !isBlind()
			M->LR_PRODUTO := aCols[n][nPosProd] 
		EndIf
	EndIf
EndIf

RestArea(aArea)		// Restaura area anterior

Return Nil

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7VlTran ºAutor  ³ Vendas Clientes    º Data ³  03/07/14   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a validacao do codigo da Transportadora informado na    º±±
±±º          ³enchoice da venda assistida                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Lj7VlTran(ExpL1)											  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpL1 - determina se inicializa o array aCrdCliente         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7VlDX3()
Local lRet	:= .T. 		// Retorno da funcao

If ReadVar() == "M->LQ_TRANSP" .AND. !Empty(M->LQ_TRANSP)
	lRet := ExistCpo("SA4", M->LQ_TRANSP)
Endif

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7AtuDescºAutor  ³ Varejo             º Data ³  20/08/2014 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Atualiza todos os descontos de referencia na MatxFis        º±±
±±º          ³ (IT_DESCONTO).                                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function Lj7AtuDesc()
Local nInd 		 := 0
Local nLinCalc 	 := 0
Local nPosValDesc:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]			// Posicao do valor de desconto
Local lRet		 := .T.

If Type("aCols") == "U"
	lRet := .F.
EndIf

If lRet
	//Atualiza s valores de desconto na MatxFis
	For nInd := 1 To Len(aCols)
		If MaFisFound("IT",nInd)
		   	//MaFisAlt("IT_DESCONTO", aCols[nInd][nPosValDesc], nInd)
		   	If MaFisRet(nInd, "IT_DESCONTO") <> aCols[nInd][nPosValDesc]
			   	MaFisLoad("IT_DESCONTO", aCols[nInd][nPosValDesc], nInd)
			   	If nLinCalc == 0
				   	nLinCalc := nInd
			   	EndIf
		   	EndIf
		EndIf
	Next nInd
	
	If nLinCalc > 0
		MaFisRecal("",nLinCalc)
		MaFisEndLoad(nLinCalc,1)
		StaticCall( MATXFIS, MaIt2cab )
	EndIf
EndIf

Return

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7LimpDesºAutor  ³ Varejo             º Data ³  20/08/2014 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Limpa todos os descontos de referencia na MatxFis           º±±
±±º          ³ (IT_DESCONTO).                                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Static Function Lj7LimpDes()
Local nInd 		 := 1
Local nLinCalc 	 := 0
Local nPosValDesc:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]			// Posicao do valor de desconto

If Type("aCols") == "U"
	Return
EndIf

While MaFisFound("IT",nInd)
	MaFisLoad("IT_DESCONTO", 0, nInd) //Retira da MATXFIS, todos os descontos para recalcular
	nInd++
End

//Recalcula MatxFis
For nInd:=1 To Len(aCols)
	If MaFisFound("IT",nInd)
		MaFisRecal("IT_DESCONTO",nInd)
	EndIf
Next nInd

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7TpFreteºAutor  ³ Varejo             º Data ³  31/03/2015 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Retorna o Tipo de Frete definido.                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7TpFrete(cCliCod,cCliLoja)
Local cRet 		:= ""
Local aAreaSA1 	:= {}
Local cEstCli 	:= ""
Local cTipoCli  := ""

If !Empty(cCliCod) .And. !Empty(cCliLoja)
	aAreaSA1 := SA1->(GetArea())
	DbSelectArea("SA1")
	SA1->( DbSetOrder(1) )
	If SA1->( DbSeek(xFilial("SA1")+cCliCod+cCliLoja) )
		cEstCli := SA1->A1_EST
		cTipoCli:= SA1->A1_TIPO
	EndIf
	RestArea(aAreaSA1)
Else
	cEstCli := SA1->A1_EST
	cTipoCli:= SA1->A1_TIPO
EndIf

//Se for Cliente "Consumidor Final" e "Estrangeiro", envia como "S" (Sem Frete), para que seja o codigo do CFOP seja montado corretamente na MatxFis
//Importante: o campo Venda Presencial (F4_VENPRES) deve estar igual a 1
If cTipoCli == "F" .And. cEstCli == "EX"
	cRet := "S" //Sem Frete
EndIf

Return cRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7VldServºAutor  ³ Varejo             º Data ³  12/03/2015 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida desconto na venda com Servicos Financeiros.         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function Lj7VldServ()

Local lRet 	 	:= .T. //Retorno da validacao
Local lSFinanc 	:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)	//Valida implementação do servico financeiro
Local cMvLjTSF	:= SuperGetMV("MV_LJTPSF",,"SF")	// Tipo Servico Financeiro
Local nPosItSer	:= 0 //Posicao Item Servico
Local nItem		:= aScan(aHeader,{|x| Upper(Alltrim(x[2])) == "LR_ITEM"}) //Posicao do item
Local nProduto	:= aScan(aHeader,{|x| Upper(Alltrim(x[2])) == "LR_PRODUTO"}) //Posicao do Produto
Local nColPosDel 	:= Len(aHeader) + 1 //Posicao deletado
Local nI			:= 0 //Contador

//Validacao de desconto na venda com Servicos Financeiros
If lSFinanc
	nPosItSer := Ascan(aHeader,{|x| Alltrim(Upper(x[2])) == "LR_ITEMCOB"})

	//Verifica se existem Servicos Financeiros na Venda
	If aScan(aCols, {|x|, !Empty(x[nPosItSer]) .And. !x[nColPosDel]}) > 0
		MsgAlert(STR0111) //#"Não é permitido desconto nesta venda pois possui Serviços Financeiros, efetue o desconto diretamente no item."
		lRet := .F.
	Else
		For nI := 1 To Len(aCols)
			If !aCols[nI][nColPosDel] .And. Posicione("SB1", 1, xFilial("SB1") + aCols[nI][nProduto], "B1_TIPO") ==  cMvLjTSF
				MsgAlert(STR0111) //#"Não é permitido desconto nesta venda pois possui Serviços Financeiros, efetue o desconto diretamente no item."
				lRet := .F.
			EndIf
		Next nI
	EndIf
EndIf

Return lRet


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7T_Quant	  ³  Autor³ Gorgulho	     ³ Data ³02/09/15 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Pertencente ao grupo das funcoes de Totais, tem como		  ³±±
±±³          ³ objetivo manipular o sub-total da venda				  	  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7T_Quant(nExp1, uExp2)					                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ nExp1 - O que se deseja manipular o valor 		 		  ³±±
±±³          ³ uExp1 - Qual valor deve conter (em caso de alteracao)	  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para nExp1, tem-se:										  ³±±
±±³          ³ 1 - Titulo												  ³±±
±±³          ³ 2 - Valor												  ³±±
±±³          ³ 3 - Objeto												  ³±±
±±³          ³ 4 - Picture												  ³±±
±±³          ³ 															  ³±±
±±³          ³ Exemplos:												  ³±±
±±³          ³ Para alterar o titulo do sub-total				  		  ³±±
±±³          ³ Lj7T_Quant(1, "Quant")									  ³±±
±±³          ³ 															  ³±±
±±³          ³ Para receber o titulo da Quantidade						  ³±±
±±³          ³ Lj7T_Subtot(1)								  			  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7T_Quant( nTipo, uParam )

If !Lj7T_VlTp(nTipo, "Lj7T_Quant", uParam)
	Return .F.
EndIf

Return Lj7T_Array( 7, nTipo, uParam )


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³ Lj7T_Quant	  ³  Autor³ Gorgulho	     ³ Data ³02/09/15 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄ´±±
±±³Descricao ³ Soma quantidade de itens total							  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³ Lj7CalcQtd(nExp1)						                  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³ aCols											 		  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso		 ³ LOJA701 													  ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CalcQtd(aCols,nLinha,nQuant)

Local nX 		:= 1
Local nAuxQuant := 0
Local nPosQuant	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]	// Posicao da Quantidade

Default nQuant := 0
Default nLinha := 0

For nX := 1 To Len(aCols)

	If !aCols[nX][Len(aCols[nX])]

		If nLinha == nX	.AND. nQuant > 0
			nAuxQuant += nQuant
		Else
			nAuxQuant += aCols[nX][nPosQuant]
		EndIf

    EndIf

Next nX

Return (nAuxQuant)

//-------------------------------------------------------------------
/*/{Protheus.doc} VldLJ7104
@description Funcao para validacao do Retorno do Ponto de Entrada LJ7104
@author Rene Julian
@since 10/08/2016
@version 11.80
/*/
//-------------------------------------------------------------------

Static Function VldLJ7104(aLJ7104,nPerDesc,nVlrDesc )
Local lRet			:= .T.
Local nX   	 	:= 0
Local nTotVDesc 	:= 0
Local nTotPDesc 	:= 0
Local laCols 		:= .T.
Local nPosIT   	:= Ascan(aHeader,{|x| AllTrim(Upper(x[1])) == "LR_ITEM"})
Local nPItPE		:= 0
Local cItem 		:= ""

/*/Estrutura do Array aLJ7104
1 - Item  					- Caracter
2 - Codigo Produto 			- Caracter
3 - Valor do Desconto		- Numerico
4 - Percentual do Desconto	- Numerico
/*/

For nX := 1 to Len(aLJ7104)
	If Len(aLJ7104[nX]) >= 4 .And. (ValType(aLJ7104[nX][3]) == "N" .And. ValType(aLJ7104[nX][4]) == "N")
		nTotVDesc += aLJ7104[nX][3]
		nTotPDesc += aLJ7104[nX][4]
	EndIf

	nPItPE := Ascan(Acols ,{|x| AllTrim(Upper(x[1])) == aLJ7104[nX][1] })

	If nPItPE == 0
		laCols := .F.
		Exit
	EndIf

Next nX

// Caso a Somatoria do Desconto em percentual ou em valor seja Diferente nao validamos a Modificacao.
If  nTotVDesc <> nVlrDesc
	MSgAlert(STR0112) //"Valor do Desconto aplicado nos Itens Difere do Valor Total do Desconto"
	lRet := .F.
EndIf

// Caso o seja passado um item que nao esteja no aCols invalidamos a modificacao.
If !laCols
	MSgAlert(STR0113 ) //"Codigo do Item Inexistente, Não sera aplicado o desconto por item."
	lRet := .F.
EndIf

Return lRet

//-------------------------------------------------------------------
/*/{Protheus.doc} LJ7AplDesc
@description Funcao para Alterar o Desconto de Total para desconto nos Itens
			 o Rateio esta sendo enviado pelo cliente pelo ponto de entrada.
@author Rene Julian
@since 10/08/2016
@version 11.80
/*/
//-------------------------------------------------------------------

Function LJ7AplDesc(aLJ7104)
Local nPosVdesc	:= Ascan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_VALDESC"})
Local nPosPdesc	:= Ascan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_DESC"})
Local nPosIT	:= Ascan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_ITEM"})
Local nPosVlrI	:= Ascan(aHeader,{|x| AllTrim(Upper(x[2])) == "LR_VLRITEM"})
Local nItem     := 0
Local nX 		:= 0
Local nBKP      := 0
Local nTotal    := 0
Local __bkpRead := ReadVar()

For nX := 1 to Len(aLJ7104)
	nItem := Ascan(aCols,{|x| AllTrim(Upper(x[nPosIT])) == aLJ7104[nX][1] })
	
	If nItem > 0	
		__Readvar := "M->LR_VALDESC"
		M->LR_VALDESC := aLJ7104[nX][3]
		nBKP := n
		n	 := nItem
		lj7VlItem(4,nil,nil,nil,.F.,0)
		n 	 := nBKP
	EndIf
	
Next nX

__Readvar := __bkpRead

Return()

//-------------------------------------------------------------------
/*/{Protheus.doc} LjArredSat
@description Funcao para ajuste de arredondamento conforme ABNT NBR 5891
@author Varejo
@since 28/09/2016
@version 11.80
/*/
//-------------------------------------------------------------------
Function LjArredSat(nValor, nTamValor)

Local cValDec  	:= Subs(CValToChar(nValor), At(".", CValToChar(nValor)) + 1, Len(CValToChar(nValor))) //String do valor 
Local nLenDec	:= Len(cValDec) //Tamanho dos decimais
Local lUseSat	:= IIF(ExistFunc("LjUseSat"), LjUseSat(), .F.)
Local nVlrAux	:= nValor //Valor auxiliar

Default nTamValor := TamSx3("D2_TOTAL")[2] //Tamanho de casas decimais a serem arredondadas

//Inicializa arredondando
nValor := Round(nVlrAux, nTamValor)

If lUseSat
	//Verifica se casas decimais superiores ao tamanho do campo e se segundo valor decimal é par	
	If nLenDec > nTamValor .And. Mod(Val(Subs(cValDec, nTamValor, 1)), 2) == 0
		If Len(SubStr(cValDec, nTamValor + 1, nLenDec)) > 1 //Verifico quantos digitos tem logo a pos a casa decimal a ser mantida
			If Val(SubStr(cValDec, nTamValor + 1, nLenDec)) <= Val("5" + Replicate("0", Len(SubStr(cValDec, nTamValor + 2, nLenDec))))				
				nValor := NoRound(nVlrAux, nTamValor)							
			EndIf
		Else
			If Val(SubStr(cValDec, nTamValor + 1, nLenDec)) <= 5 //se tem apenas 1 digito, verifica se é maior que 5								
				nValor := NoRound(nVlrAux, nTamValor)			
			EndIf
		EndIf	
	EndIf
EndIf

Return nValor

//-------------------------------------------------------------------
/*/{Protheus.doc} LjSatMxFis
@type Function
@description Funcao para ajuste da referencia, setando SAT na MatxFis
@author Varejo
@since 03/11/2016
@version 11.80
/*/
//-------------------------------------------------------------------
Function LjSatMxFis()
Local lJob	  := IsBlind()
Local lUsaSat := IIF(ExistFunc("LjUseSat"), LjUseSat(), .F.)
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

If !lFtvdVer12 .And. lUsaSat
	If !lEmiteNF
		If lJob
			MaFisAlt("NF_SERSAT",SL1->L1_SERSAT)
		Else
			MaFisAlt("NF_SERSAT",LJGetStation("SERSAT"))
		EndIf
	Else
		MaFisAlt("NF_SERSAT", Space(Len(SL1->L1_SERSAT)))  // estacao SAT mas ira emitir NF, nao seta SAT na Matxfis
	EndIf
EndIf

Return NIL

//-------------------------------------------------------------------
/*/{Protheus.doc} LjNewCalVl
@type Function
@description Valida datas dos fontes para usar desconto no total na 
MatxFis com ICMS Solidario
@author Varejo
@since 03/11/2016
@version 11.80
/*/
//-------------------------------------------------------------------
Function LjNewCalVl()
Local lRet := .F.

If lDtFontes == Nil
	lDtFontes := cPaisLoc == "BRA" .And.;
			GetApoInfo("LOJA701A.PRW")[4] >= Ctod("20/01/2017") .And.;
			GetApoInfo("LOJA701B.PRW")[4] >= Ctod("20/01/2017") .And.;
			GetApoInfo("LOJA701C.PRW")[4] >= Ctod("20/01/2017")
EndIf

lRet := lDtFontes

Return lRet

//-------------------------------------------------------------------
/*/{Protheus.doc} LjNewCalSol
@type Function
@description Valida se venda possui ICMS solidario e se os 
fontes estão tratando desconto no total da MatxFis
@author Varejo
@since 03/11/2016
@version 11.80
/*/
//-------------------------------------------------------------------
Function LjNewCalSol()
Local lRet := .F.
 
lRet := LjNewCalVl() .And. IIF(MaFisFound("NF"), MaFisRet(,"NF_VALSOL") > 0, .F.)

Return lRet


//-------------------------------------------------------------------
/*/{Protheus.doc} LjRestSol
@type Function
@description Zera os valores de desconto da MatxFis, restaura o 
solidario e o desconto no item, caso haja
@author Varejo
@since 19/01/2017
@version 11.80
/*/
//-------------------------------------------------------------------
Function LjRestSol()
Local nVlrIcmSol:= 0
Local nX		:= 0
Local nPosValDesc:= 0

If LjNewCalSol() .And. ValType(aCols) == "A" //Qdo vou finalizar um orçamento e vou finalizar, não tenho o aCols
	nPosValDesc := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]
	nVlrIcmSol	:= Lj7IcmsSol()
	Lj7T_Subtotal(2, Lj7T_Subtotal(2) - nVlrIcmSol)
	MaFisAlt("NF_DESCONTO",0)

	For nX := 1 to Len(aCols)
		If !aCols[nX][Len(aCols[nX])] .And. aCols[nX][nPosValDesc] > 0
			MaFisAlt("IT_DESCONTO", aCols[nX][nPosValDesc] , nX)
		EndIf		
	Next nX
	
	nVlrIcmSol := Lj7IcmsSol()
	Lj7T_Subtotal(2 , Lj7T_Subtotal(2) + nVlrIcmSol)
EndIf

Return

//-------------------------------------------------------------------
/*/{Protheus.doc} LjDescFis
@type Function
@description    Ajusta os valores de desconto na MatxFis para resgatar o 
			    valor correto de Impostos calculado pela MatxFis
@author Varejo
@since 19/01/2017
@version 11.80
/*/
//-------------------------------------------------------------------
Function LjDescFis(nDescTotAnt, nDescTotAtu)
Local nVlrTotal 	:= 0

Default nDescTotAnt	:= 0
Default nDescTotAtu := 0

If LjNewCalVl() .And. MaFisFound("NF") .And. ( (nDescTotAnt + nDescTotAtu > 0) .And.;
 	( nDescTotAnt <> nDescTotAtu )) .Or.  (!Empty(SL1->L1_DOC) .Or. !Empty(SL1->L1_DOCPED))
	
	//Faz o tratamento somente se existir IPI ou ICMS Solidário
	If MaFisRet(Nil,"NF_VALIPI") > 0 .Or. MaFisRet(Nil,"NF_VALSOL") > 0
		If INCLUI .Or. ALTERA .Or. (Empty(SL1->L1_DOC) .And. Empty(SL1->L1_DOCPED)) //Nao recalcular total e subtotal quando visualizacao de orcamento finalizado 
			LjGrvLog( Nil, "Existe valor de IPI ou Solidário + Desconto no Total dessa venda")
				 	
			/*Aplica o desconto total na Referencia "NF_DESCTOT" da MatxFis 
			(Especifica para uso do LOJA), faz o rateio do desconto conforme regra do LOJA*/
			MAFisAlt("NF_DESCTOT", nDescTotAtu )
		 
			//Atualiza os valores de Sub-Total e Total da Venda
			nVlrTotal := MaFisRet(, "NF_TOTAL" ) + nDescTotAtu
		Else
			//Orcamento finalizado
            //Resgata os valores de Sub-Total e Total da Venda
            nVlrTotal := SL1->L1_VLRTOT + SL1->L1_DESCONT
		EndIf
		
		LjGrvLog( Nil,"Referência NF_DESCTOT alterada com o valor de desconto :[$" + cValToChar(nDescTotAtu) + "]")
		LjGrvLog( Nil,"Novo Total Calculado (NF_TOTAL + DescontoAtual) :[$" + cValToChar(nVlrTotal) + "]")
		
		Lj7T_Subtotal(2 , nVlrTotal)
        Lj7T_Total(2 , nVlrTotal)
	EndIf
EndIf

Return

//-------------------------------------------------------------------
/*/{Protheus.doc} Lj7GeMod5()
@type Function
@description    Se o nModulo for 5 (SIGAFAT), 
			    aparecerá mensagem na tela bloqueando a seleção
			    de Garantia Estendida.
@author Varejo
@since 11/05/2018
@version 12.1
/*/
//-------------------------------------------------------------------
Function Lj7GeMod5()

If (!lEmitAvsGE)	//Só avisa se parâmetros de GE ou SFinanc estiverem ativos - variável Static
	If !IsBlind()
		MsgAlert(STR0128 + " " + STR0129) //"Näo é permitido o uso de Garantia Estendida ou Serviços Financeiros no Venda Direta."###"Favor utilizar o SIGALOJA/Venda Assistida."
	Else 
		ConOut(STR0128 + " " + STR0129)//"Näo é permitido o uso de Garantia Estendida ou Serviços Financeiros no Venda Direta."###"Favor utilizar o SIGALOJA/Venda Assistida."
		Help( " ", 1, "Help",, STR0128 + " " + STR0129, 1, 0 )			
	EndIf
	LjGrvLog( Nil, STR0128 + " " + STR0129)
	lEmitAvsGE := .T.	//Variável Static
EndIf

Return nil
