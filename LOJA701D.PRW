#INCLUDE "LOJA701D.CH" 
#INCLUDE "PROTHEUS.CH"
#INCLUDE "AUTODEF.CH"
#DEFINE TEF_SEMCLIENT_DEDICADO	"2"         //Utiliza TEF Dedicado Troca de Arquivos                      
#DEFINE TEF_COMCLIENT_DEDICADO	"3"			//Utiliza TEF Dedicado com o Client
#DEFINE TEF_DISCADO           	"4"			//Utiliza TEF Discado 
#DEFINE TEF_LOTE               	"5"			//Utiliza TEF em Lote
#DEFINE TEF_CLISITEF			"6"			//Utiliza a DLL CLISITEF
#DEFINE _FORMATEF				"CC;CD"     //Formas de pagamento que utilizam operação TEF para validação
#DEFINE	 CRLF					Chr(10)+Chr(13)

Static cGetCliDir      // Guarda o caminho do rootPath
Static cProfStr1       // Armazena a informacao da Condicao de Pagamento do SIGALOJA.INI
Static lImpCpfNpj	:= .F.
Static lHomTef		:= ExistFunc("LJHOMTEF") .AND. LJMSSM0(SM0->M0_CGC) 	// Indica se eh homologacao TEF
Static lMVLJPDVPA 	:= LjxBGetPaf()[2] 										//Indica se é pdv   
Static aFormaPgtos	:= {}	//guardara o rateio da das formas de pagamento no valor do cupom fiscal
Static lIsPafNfce	:= STBPafNfce()					//Usa NFC-e com PAF ?

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7ImpCF  ºAutor  ³Vendas Clientes     º Data ³  18/08/02    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a impressao do cupom fiscal                              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := Lj7ImpCF()                                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³lTefOk:=Resultada da transacao TEF                           º±±
±±º          ³ExpC2 :=Numero do cupom fiscal(utilizado para concomitancia) º±±
±±º          ³ExpC3 :=Numero do PDV(utilizado para concomitancia)		   º±±  
±±º          ³ExpA2 :=Array com os valores de acrescimos dos ítens, o sis- º±±  
±±º          ³        tema não grava o valor do acrescimo por item e a fun-º±±
±±º          ³        cao nao tem de onde buscar na hora da impressao.     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpA1 - Array contendo:                                      º±±
±±º          ³        [1] - .T. / .F. Se conseguiu completar a impressao   º±±
±±º          ³        ou teve algum erro                                   º±±
±±º          ³        [2] - Array contendo:                                º±±
±±º          ³              Se a 1a posicao for .T.:                       º±±
±±º          ³              [2][1] - Numero do cupom                       º±±
±±º          ³              [2][2] - Numero do PDV                         º±±
±±º          ³              Se a 1a posicao for .F.:                       º±±
±±º          ³              [2][1] - Codigo do Erro                        º±±
±±º          ³              [2][2] - Descricao do Erro                     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                      º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ImpCF( lTefOk    	, cNumeroCup   	, cNumeroPDV	, cMsgResg  ,;
                   aVlrAcres 	, cLQFrete     	, nVlrAcrsFi	, lCartao 	,;
                   aSitTrib		, nFatorRes 	, nFatorVen		, aTaxJuros ,;
                   cNfRPS 		, cSerRPS 		, nVlrGar		,nTotImpNCM	, ;
                   nTotVLRNCM	, nTotImpFED	, nTotImpEST	,nTotImpMUN ,;
                   cNumNotaCF)
                     
Local aArea			 := Lj7GetArea( {"SL1","SL2","SL4","SA1","SA3"} )	//Get Area nos alias
Local aRet			 := {.F.,'',''}									//Retorno da funcao
Local aFormaAux		 := { }												//Array para TEF
Local lRet			 := .T.												//Retorno da Funcao
Local nRet 			 := 0												//Retorno de verificao em ECF
Local nX			 := 0												//Controle de Loop
Local nItem 		 := 0												//Item
Local nAliquota		 := 0												//Aliquota
Local nAcrescimo	 := 0												//Acrescimo
Local nDesconto 	 := 0												//Desconto
Local cNumCupom 	 := Space(TamSX3("L1_NUM")[1])						//Numero do Cupom
Local cNumPdv 		 := Space(TamSX3("L1_PDV")[1])						//Numero do PDV
Local cSitTrib		 := ""												//Situacao Tributaria
Local cCodProd 		 := ""												//Codigo do Produto
Local cDescriProd	 := ""												//Descricao do Produto
Local cQuant 		 := ""												//Quantidade
Local cVrUnit		 := ""												//Valor Unitadorio
Local cDesconto		 := ""												//Desconto
Local cVlrItem		 := ""												//Valor do item
Local cFormaPgtos	 := ""												//Forma de Pagamento
Local cMensagem 	 := ""												//Mensagem
Local cMenImpNCM	 := ""												//Mensagem
Local cMvLjFisMs	 := SuperGetMv("MV_LJFISMS",,"")					//Conteudo da variavel MV_LJFISMS
Local cRetorno		 := Space(10)										//Retorno
Local lAcrs          := .T.												//Se tem acrescimo
Local nVlrIcmsRet	 := 0 												//Valor do icms retido (substituicao tributaria) - Item
Local nVlrTotIcmsRet := 0												//Valor do icms retido (substituicao tributaria) - Total
Local cTpSolCf       := SuperGetMv("MV_TPSOLCF")                  		//Parametro para validacao do tipo de cliente para o calculo do solidario
Local cVinculado	 := "0"												//Indica se eh cupom vinculado
Local nAliqRed		 := 0											    //Aliquota de reducao da base de calculo do produto
Local lLj7013		 := ExistBlock("LJ7013",Nil,.T.)				    //Indica se existe o ponto de entrada
Local aRetLj7013	 := {}												//Array do ponto de entrada
Local cUnidMed       := " "												//Unidade de medida
Local cDinheiro		 := ""												// Descricao da forma de pagamento R$ (sera alimentada com o conteudo da tabela 24 do SX5) 
Local cCodProdTmp	 := ""												// Codigo de produto temporario
Local lVAssConc	     := LjVassConc()									//Indica se o cliente utiliza a Vda Assistida Concomitante
Local aTamL2_VRUNIT  := TamSX3("L2_VRUNIT")                 			// Tamanho do campo L2_VRUNIT
Local aTamL2_VALDESC := TamSX3("L2_VALDESC")                			// Tamanho do campo L2_VALDESC
Local aTamL2_VLRITEM := TamSX3("L2_VLRITEM")                			// Tamanho do campo L2_VLRITEM
Local lFunImp		 := .F.												// Se a funcao da impressora eh 01 no LojxEcf
Local lVerHora		 := .T.												// Se a hora eh para verificar a hora, dependendo do retorno do LojxEcf
Local nVlrItem       := 0												// Valor do Item somado aos impostos para impressao no ECF em Localizacoes
Local nI             := 0												// Contador Impostos Variaveis
Local nValorIcms		:= 0												// valor de icms da venda para Nota Legal - DF
Local nValorIss		:= 0												// valor de iss da venda para Nota Legal - DF
Local nValImp        := 0												// Valor total dos Impostos Variaveis
Local aImps          := {}												// Array com os Impostos Variaveis 
Local cIndImp															// Indice dos Impostos Variaveis
Local cCampoVal															// Valor do Imposto Variavel
Local cCampoAlq															// Aliquota do Imposto Variavel
Local cAuxRetMsg		:= ""												//Variavel auxiliar para o retorno das mensagens
Local nValorItem     := 0												// Valor total da venda por item
Local aContCols		 := {}												// Contador Auxiliar
Local nDescPro		 := 0												// Acumula o Desconto Proporcional
Local lLjSimpNac 	 := SuperGetMV("MV_LJSIMPN",,.F.)					// Verifica se a empresa e optante do Simples Nacional
Local lUsafd      	 := SuperGetMV("MV_LJUSAFD",,.F.) 					// Utiliza Fidelizacao de cliente ??
Local aLjExcecao	 := {}
Local lExcecaoFcl	:= .F.
Local LExecPE7017	:= .F.
Local lCalcFin		 := (SuperGetMv("MV_CALCFIN",,"M")== "F")  		// Variavel para controle do parametro MV_CALCFIN = [F]inanciado
Local nTPCompNCC     := SuperGetMV("MV_LJCPNCC",,1)						// Tratamento para compensacao de NCC
Local lNfe			 := .F.												// Define se chama ou nao a tela de CNPJ/CPF
Local lPreVenda		 := SuperGetMv("MV_LJPRVEN",,.F.) 					// Indica se a integracao com o cenario de vendas esta ativa
Local lNumOrc		 := SL1->(ColumnPos("L1_NUMORC") ) > 0   			// Indica a existencia do campo
Local nMvLjTpDes	 := SuperGetMv( "MV_LJTPDES", , 0 )
Local lImpItem		 := .T.												// Verifica se item é do tipo retira para realizar a impressão
Local lTemReserva	 := .F.												// Verifica se possui item com reserva
Local nPosStTrib	 := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_SITTRIB"})// Posicao do codigo da reserva
Local nValRes	 	 := 0												// Valor dos itens com reserva
Local cRet   		 := "" 												// Caracter de retorno
Local cImpRGer  	 := SuperGetMV("MV_RELGART",,"U_LOJR600A") 			// Nome do funcao que imprime relatorio gerencial
Local cMvLjTGar		 := SuperGetMV("MV_LJTPGAR",,"GE")                 	// chama a user function
Local cCodProdRG	 := ""                                             	// codigo produto relatorio gerencial 
Local cDescPrdRG	 := ""                                             	// Descrição produto relatorio gerencial 
Local cVlrItemRG	 := ""                                             	// Vlr do produto
Local cNSerieRG      := ""                                             	// nSerie
Local nRG			 := 0                                              	// Numero Relatorio gerencial 
Local nRA			 := 0                                               // Relatório Gerencial
Local nCont			 := 1                                              	// Contador
Local aRelGer		 := {}                                             	// Rel. gerencial 
Local aRelGar		 := {}                                             	// Rel. garantia estendida 
Local lGE			 := ExistFunc("LjUP104OK") .AND. LjUP104OK()		// Validação do Conceito Garantia Estendida
Local lNumGar		 := SL2->( FieldPos("L2_GARANT") ) > 0   			// Indica a existencia do campo
Local lPafEcf		 := LjNfPafEcf(SM0->M0_CGC)
Local cCpfCgcCli     := ""												//Usado para retornar o cpf/cnpj do cliente quando usar PBLegal
Local nVlrTotIPI	 := 0												//valor total de IPI
Local lExistIPI		 := .F.												//verifica se existe algum item com ipi na venda
Local nDescICMS		 := 0												// Acumula o Desconto de ICMS a ser deduzido
Local lTentarNovamente := .F.											// Tentar enviar comando ao ECF novamente?

Local lMVLJPRDSV   	 := SuperGetMv("MV_LJPRDSV",.F.,.F.) 				// Verifica se esta ativa a implementacao de venda com itens de "produto" e itens de "servico" em Notas Separadas
Local nVlrServic	 := 0 												// Valor dos itens de "Servico"
Local lTemItProd	 := .T.												// Indica se tem ou nao itens de "Produto" na venda para imprimir no Cupom Fiscal
Local aNotaRPS 		 := {}												// Array com informacoes do Numero e Serie da NF de "Servico" (RPS)
Local lIsRecCel 	 := .F.												// Indica que eh produto "Recarga de Celular"
Local lCondNeg     	 := ( Alltrim( SL1->L1_CONDPG ) == "CN" )    			// VerIfica se eh condicao negociada

Local lFTVD7013		:= ExistBlock("FTVD7013")							//Indica se existe o ponto de entrada
Local aRetFTVD7013	:= {}												//Array do ponto de entrada
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12   := LjFTVD()						// Indica que foi acionada pela rotina Venda Direta. 
Local lVendDireta   := Iif(lFtvdVer12, .T., .F.)						// Indica que foi acionada pela rotina Venda Direta. 
Local nItemImp		:= 0												// Totaliza o total de itens a serem impressos
Local lItemDel		:= .F.												// Regra do PAF-ECF para imprimir e cancelar o item
Local lFunTesISS  	:= ExistFunc("LjIsTesISS")
Local lIsVendaVP 	:= If(ExistFunc("Lj7VPNew") .And. Lj7VPNew(),Lj7VPYesNo()=="S",.F.)	// Indica se eh venda de Vale Presente
Local lLjIcmJr		:= ChkIncICMS()
Local lSFinanc		:= AliasIndic("MG8") .AND. SuperGetMV("MV_LJCSF",,.F.)// Validação do Conceito servico financeiro
Local cMvLjTSF		:= SuperGetMV("MV_LJTPSF",,"SF")	// tipo servico financeiro
Local aRelSF        := {} // Rel. servico financeiro
Local lIsVdRecCP 	:= If(ExistFunc("Lj7CP_OK") .And. Lj7CP_OK(),Lj7CPGetSt()=="S",.F.)	// Indica se eh venda de Recarga de Cartao Presente (Gift Card)
Local lF4MKPSOL 	:= SF4->(ColumnPos("F4_MKPSOL")) > 0
Local nValFECP		:= 0
Local aAreaSL1		:= {}
Local aSubPgto		:= {}
Local nSubTPag		:= 0
Local nDifPag		:= 0
Local aRetInfDocCli	:= {}
Local cCpfCli		:= ""
Local lMvTroco		:= SuperGetMv("MV_LJTROCO",,.F.)
Local nTroco		:= 0 
Local lL2CEST       := SL2->( ColumnPos("L2_CEST") ) > 0
Local lB1CEST       := SB1->( ColumnPos("B1_CEST") ) > 0
Local cCest         := ""
Local cNomeProg	:= Iif(lFtvdVer12,"FATA701","LOJA701") //Nome da Rotina

Private lEntrega     := .F.                                				// Verifica se o orçamento eh de Entrega ( .T. -> Orcamento do tipo "Entrega" , .F. -> Orcamento do tipo "Retira" ) 
Private lUsaCartao   := .F.												// Verifica se utiliza Cartao de Credito/Debito na Venda
Private lUsaRegime   := .F.												// Verifica se esta sendo utilizado o Regime Especial - Orcamento com reserva: Campo SL1->L1_ORCRES nao vazio. 

DEFAULT cMsgResg	 := ""					                			// Imprime o nro do vale compra resgatado
DEFAULT	cLQFrete	 := ""												// Recebe conteudo do campo LQ_TPFRET 1- CIF 2- FOB
DEFAULT nVlrAcrsFi	 := 0												// Valor default zero para juros sobre valor financiado
DEFAULT lCartao		 := .F.												// Indica se teve cartao na venda
DEFAULT nFatorRes	 := 1
DEFAULT nFatorVen	 := 1 
DEFAULT aSitTrib	 := {}
DEFAULT aTaxJuros	 := {}
DEFAULT cNfRPS		 := "" 												// Numero da NF de Servico "RPS"
DEFAULT cSerRPS		 := "" 												// Serie da NF de Servico "RPS"
DEFAULT nVlrGar      := 0 												// Valor da Garantia
DEFAULT nTotImpNCM	:= 0
DEFAULT nTotImpFED	:= 0
DEFAULT nTotImpEST	:= 0
DEFAULT nTotImpMUN	:= 0
DEFAULT nTotVLRNCM 	:= 0
Default cNumNotaCF	:= ""

//Somente considera ativa a implementacao de venda com itens de "produto" e itens de "servico" em Notas Separadas, se a venda nao for com "Reserva" e nao for concomitante
lMVLJPRDSV := lMVLJPRDSV .And. Empty(SL1->L1_ORCRES) .And. Empty(SL1->L1_DOCPED) .And. !lVAssConc
lTemItProd := If(lMVLJPRDSV,.F.,.T.)

If lMVLJPRDSV .And. ExistFunc("LjCheckRPS")    
	LjCheckRPS(SL1->L1_NUM, @lTemItProd, Nil)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se esta com venda Assistida concomitante ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If !lVAssConc .And. !lIsVendaVP .And. !lIsVdRecCP

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Alimenta a variavel com a descricao da forma de pagto        ³
	//³ dinheiro                                                     ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea("SX5")
	DbSeek(xFilial("SX5")+"24R$")
	cDinheiro := AllTrim(X5Descri())

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica a data da impressora, nao permite a impressao se a  ³
	//³ data do ECF for diferente da data do sistema                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If LjEcfIFData( @lFunImp, @lVerHora )
		If !lFunImp 	    
			If !VerifHora()
				/* "Conforme previsto no Requisito XVII (Ato Cotepe/ICMS 9, de 13 de Março de 2013),
					para PAF-ECF admite-se somente uma tolerância em minutos entre a hora do Sistema e a hora do ECF,
					limitada a uma hora, desde que na mesma data." */
				If lMvLjPdvPa
					aRet[3]:=STR0081
				Else
				    aRet[3]:=STR0001 //"Data do ECF diferente da data do Sistema"
				EndIf

				Return( aRet )
			EndIf
		Else
			If !lVerHora
			    aRet[3]:=STR0001 //"Data do ECF diferente da data do Sistema"
				Return( aRet )				
			EndIf		
		EndIf
	EndIf
	
    If cGetCliDir == NIL
    	cGetCliDir := GetClientDir()
    EndIf 	
	
	If !File( cGetCliDir+"SIGALOJA.INI" )
		LjGrvLog( M->LQ_NUM, "Arquivo SIGALOJA.INI criado com a Sessão [Condicao de Pagamento], Chave Retencoes = Retencoes." +;
						" Vide a existência dessa forma de pagamento no ECF")
						
		WritePProString("Condicao de Pagamento", "Retencoes", "RETENCOES", cGetCliDir+"SIGALOJA.INI")
	EndIf
	
	If !lHomTef
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Verifica se ha um cupom em aberto. Caso afirmativo, faz o    ³
		//³ cancelamento antes da abertura de outro                      ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nRet := IFStatus( nHdlECF, '5', @cRetorno )
		If nRet == 7
			nRet := IFCancCup( nHdlECF )
			If Lj7VerCmd( nRet )
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ dá um tempo para a impressora fazer a impressao do cancelamento³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				Inkey(8)   
			Else
		        aRet[3]:=STR0002 //"Falha no cancelamento do cupom"
				Return ( aRet )
			EndIf
		EndIf
	EndIf
	
	If ! SuperGetMV("MV_LJREST",,.F.)	//Variavel utilizada no sistema de restaurante
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Tratamento que verifica se os itens da venda  ³
		//³sao do tipo servico e o municipio e Joinville ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Lj950CheckRPS(SL1->L1_NUM,SA1->A1_RECISS)
			lNfe	:= .T.
		EndIf	
		
		If lTemItProd
			If !lHomTef
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Abre o cupom fiscal                                          ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				nRet := IFAbreCup(nHdlECF, @cCpfCgcCli , Nil , Nil , @lImpCpfNpj,;
		 						  Nil 	 , lNfe)
	 		EndIf					
	
			If !Lj7VerCmd( nRet )
			    aRet[3]:=STR0003 //"Falha na abertura do cupom"
				Return( aRet )
			EndIf
		 	
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Pega o numero do cupom fiscal                                ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nRet := IFPegCupom( nHdlECF, @cNumCupom )
			If !Lj7VerCmd( nRet )
			    aRet[3]:=STR0004 //"Falha em pegar o numero do cupom fiscal"
				Return( aRet )
			EndIf
		Else
			//Quando nao existir itens de "produto", ou seja, existir apenas itens de "servico" na venda,
			//deve pegar o numero da NF de Servico RPS
			If lMVLJPRDSV .And. ExistFunc("LjSerNfRPS")
				//Qdo. for PAF-ECF, pega o numero do Cupom Nao Fiscal referente ao RPS, pois este numero eh provisorio, porque 
				//o numero correto da Nota de Servico RPS a ser considerado eh o da Retaguarda quando processar o LjGrvBatch na retaguarda.
				If lMVLJPDVPA
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³ Pega o numero do cupom que esta aberto                 ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					nRet := IFPegCupom( nHdlECF, @cNumCupom )
					If !Lj7VerCmd( nRet )
					    aRet[3]:=STR0004 //"Falha em pegar o numero do cupom fiscal"
						Return( aRet )
					EndIf
					cNfRPS	  := cNumCupom
					cSerRPS	  := LjGetStation("SERIE")
				Else
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Busca a Serie e Numero da Nota de Servico (RPS) a ser gerada. ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					aNotaRPS := LjSerNfRPS(lVendDireta)
					If aNotaRPS[1]
						cNumCupom := aNotaRPS[2][1]
						cNfRPS	  := aNotaRPS[2][1]
						cSerRPS	  := aNotaRPS[2][2]
					Else
					    aRet[3]:= STR0073 //"Falha em pegar o numero da Nota Fiscal de Servico (RPS)."
						Return( aRet )
					EndIf
				EndIf
			EndIf
		EndIf
		
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Pega o numero do PDV                                         ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nRet := IFPegPDV( nHdlECF, @cNumPdv )
		If !Lj7VerCmd( nRet )
		    aRet[3]:=STR0005 //"Falha em pegar o numero do PDV"
			Return( aRet )
		EndIf

		DbSelectArea("SB1")
		SB1->( DbSetOrder(1) )
		
		DbSelectArea("SB0")
		SB0->( DbSetOrder(1) )
		
		DbSelectArea("SF4")
		SF4->( DbSetOrder(1) )

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Realizado tratamento para verificar qual item do aCols        ³
		//³correspondente deve ser passado para a MaFisRet (Localizacoes)³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If cPaisLoc <> "BRA"
			If Len(aCols) > 0
				For nX := 1 To Len(aCols) 
					If !aCols[nX][Len(aHeader) + 1]
						Aadd(aContCols,nX) 
					EndIf
				Next nX
			EndIf
		EndIf

		// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
		If lMVLJPDVPA  
			SET DELETE OFF
		EndIf
		
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Imprime os itens                                             ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		nItem := 0
		DbSelectArea("SL2")
		SL2->( DbSetOrder(1) )	//L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
		SL2->( DbSeek(xFilial("SL2") + SL1->L1_NUM) )
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Ponto de controle para gerar arquivo de Log, para monitorar a impressao de cupons fiscais indevidos³
		//³LJ7Logcf('B',cNumPdv,cNumCupom,xFilial("SL2")+SL1->L1_NUM,SL2->(RECNO()))                          ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		While SL2->( !Eof() ) .AND. SL2->L2_FILIAL+SL2->L2_NUM == xFilial("SL2")+SL1->L1_NUM

			//Regra do PAF-ECF para itens cencelados de uma venda não concomitante
		    If lMVLJPDVPA .AND. SL2->(Deleted()) .AND. Empty(SL2->L2_PAFMD5)
				SL2->( DbSkip() )
				Loop
		    EndIF

			If lMVLJPDVPA .AND. SL2->(Deleted()) .AND. SL2->L2_VENDIDO=="N" .AND. !Empty(SL2->L2_PAFMD5)

				//Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
				SET DELETE ON				

				SB1->(DbSeek(xFilial("SB1")+SL2->L2_PRODUTO))
				SB0->(DbSeek(xFilial("SB0")+SB1->B1_COD))
				SF4->(DbSeek(xFilial("SF4")+SL2->L2_TES))

				If SuperGetMv("MV_CODBAR",,"N") == "S" .And. !Empty(SB1->B1_CODBAR)
					cCodProd := SB1->B1_CODBAR
				Else
					cCodProd := SL2->L2_PRODUTO
				EndIf
				
				cDescriProd	:= SL2->L2_DESCRI
				cQuant		:= StrZero(SL2->L2_QUANT,8,3)
				cUnidMed	:= SB1->B1_UM
				
				If lL2CEST
					cCest := SL2->L2_CEST
					If lB1CEST .AND. Empty(cCest)
						cCest := SB1->B1_CEST
					EndIf
				Else
					cCest := ""
				EndIf

				Lj701DVECF(@cDesconto,@cVrUnit,@cVlrItem )
				lExcecaoFcl := .F. //Não tem os itens na Matxfis para retornar a referência
				LExecPE7017 := .F.
				
				If SF4->F4_ISS == "S" .AND. ( ( ( SA1->A1_RECISS == "1" .AND. SuperGetMv("MV_DESCISS",,.F.) ) .OR. ( SA1->A1_RECISS <> "1" ) ) )
					If SB1->B1_ALIQISS > 0
						cSitTrib := "S" + AllTrim (Str( SB1->B1_ALIQISS,5,2 ))
					Else
						cSitTrib := "S" + AllTrim (Str( SuperGetMv("MV_ALIQISS"),5,2 ))
					EndIf
				ElseIf If(lF4MKPSOL,AllTrim(SF4->F4_MKPSOL)<>"1",.T.) .And. (SB1->B1_PICMRET > 0 .OR.;
				 		(SB1->B1_PICMENT > 0 .AND. ALLTRIM(SF4->F4_SITTRIB) == "60") .OR.;
				 		(lExcecaoFcl .AND. (aLjExcecao[3] > 0 .OR. aLjExcecao[16] > 0 )) );
						 .AND. SA1->A1_TIPO $ cTpSolCf .AND. SF4->F4_BSICMST <> 100
					
					cSitTrib := "F"										// Substituicao tributaria (Icms Solidario)

				ElseIf (SF4->F4_BASEICM > 0 .AND. SF4->F4_BASEICM < 100) .Or. ;
					(lExcecaoFcl .AND. (aLjExcecao[14] > 0) .And. (aLjExcecao[14] < 100))					
					
					If (ExistBlock("LJ7017") .AND. !lFtvdVer12) .OR. (ExistBlock("FTVD7017") .AND. lFtvdVer12)
						If !lFtvdVer12
							LjGrvLog( M->LQ_NUM, " Antes do PE LJ7017")
							nAliqRed := ExecBlock("LJ7017",.F.,.F.)
							LjGrvLog( M->LQ_NUM, " Retorno do PE LJ7017", nAliqRed)
						ElseIf lFtvdVer12
							LjGrvLog( M->LQ_NUM, " Antes do PE FTVD7017")
							nAliqRed := ExecBlock("FTVD7017",.F.,.F.)
							LjGrvLog( M->LQ_NUM, " Retorno do PE FTVD7017", nAliqRed)
						EndIf

						lExecPE7017 := .T.
					EndIf
					
					If !lExecPE7017 .Or.;
						( lExecPE7017 .And. (Valtype(nAliqRed) <> "N" .OR. (nAliqRed <= 0 .Or. nAliqRed >= 100)) )
						
						If LExecPE7017
							LjGrvLog( Nil, " Problema no Ponto de Entrada LJ7017 ou FTVD7017. " +CHR(10)+CHR(13)+;
											" Solução: o retorno do PE deve ser do tipo  Numerico ou o " +;
											" seu retorno não está entre 1 e 99"+CHR(10)+CHR(13)+;
											" Revise o Ponto de Entrada! " +CHR(10)+CHR(13)+;
											" Será efetuado a busca padrão nas tabelas SB0 [B0_ALIQRED]", nAliqRed)
						EndIf
						
						nAliqRed := SB0->B0_ALIQRED	 // Considero a alíquota de redução do cadastro de produtos
						
						If lExcecaoFcl
							LjGrvLog( M->LQ_NUM, " Alíquota reduzida configurada como exceção fiscal [ se campo estiver zerado preencha a redução no campo B0_ALIQRED] " , nAliqRed)
						Else
							LjGrvLog( M->LQ_NUM, " Alíquota reduzida configurada pela TES [campo F4_BASEICM - se alíquota estiver zerada preencha a redução no campo B0_ALIQRED] " , nAliqRed)
						EndIf
					EndIf
					
					cSitTrib := "T" + AllTrim(Str(nAliqRed,5,2))		// Com redução de Icms na Base de Cálculo do Imposto
				ElseIf SF4->F4_LFICM == "I"								// Isento
					If ALLTRIM(SF4->F4_SITTRIB) == "41"						
						cSitTrib := "N"
					Else						
						cSitTrib := "I"
					EndIf
				ElseIf SF4->F4_LFICM == "N" .OR. SF4->F4_LFICM == "O"	// Não sujeito a ICMS
					cSitTrib := "N"
				Else													// Com ICMS
					nAliquota := AliqIcms(	"N"	,"S",SA1->A1_TIPO,"I",;
											NIL	,.T.)
					cSitTrib := "T" + AllTrim(Str(nAliquota,5,2))
				EndIf
				
				cDescriProd := LjDscCESCF(cDescriProd,nItem,cCest)

				nItemImp++
				nRet := IFRegItem( 	nHdlECF	, cCodProd	, cDescriProd	, cQuant	, ;
									cVrUnit	, cDesconto	, cSitTrib		, cVlrItem	, ;
									cUnidMed )	

				If !Lj7VerCmd( nRet )
				    aRet[3] := STR0006 //"Falha em Registrar item"
					Return( aRet )
				EndIf

				If nRet == 0
					IFCancItem(nHdlECF,Str(nItemImp,3),cCodProd,cDescriProd,cQuant,cUnidMed,cDesconto,cSitTrib)
				EndIf

				// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
				SET DELETE OFF				

				SL2->( DbSkip() )
				Loop
			EndIf

			nItem ++            
			lImpItem := .T.            
                    
			SB1->(DbSeek(xFilial("SB1")+SL2->L2_PRODUTO))
			
			If lSFinanc .AND. cMvLjTSF == SB1->B1_TIPO
				// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
				If lMVLJPDVPA
					SET DELETE ON
				EndIf
				
				If lMVLJPDVPA
					SET DELETE OFF
				EndIf			
				
				MG8->(DbSetOrder(2))
				If MG8->(DbSeek(xFilial("MG8")+SL2->L2_PRODUTO))
					aAdd(aRelSF,{SL2->L2_PRODUTO,SL2->L2_DESCRI,Str(a410Arred(SL2->L2_VRUNIT * SL2->L2_QUANT,"L2_VLRITEM"), aTamL2_VLRITEM[1],nDecimais),;
								 ''/*SERIE*/,''/*cod. gar*/,''/*desc.gar*/,''/*vlr.gar*/})					
					If !Empty(MG8->MG8_RDMAKE)
						cImpRGer:=MG8->MG8_RDMAKE
					EndIf			 
				EndIf
			EndIf
			
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Se o produto de vendas estiver amarrado a um ³
			//³produto de garantia                          ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If lGE
				// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
				If lMVLJPDVPA
					SET DELETE ON
				EndIf

				SB1->(DbSeek(xFilial("SB1")+SL2->L2_PRODUTO))

				If lMVLJPDVPA
					SET DELETE OFF
				EndIf

		   		If  !Empty(SL2->L2_GARANT) .AND. lNumGar
					cCodProdRG	:= SL2->L2_PRODUTO
					cDescPrdRG	:= SL2->L2_DESCRI
					cVlrItemRG	:= Str(a410Arred(SL2->L2_VRUNIT * SL2->L2_QUANT,"L2_VLRITEM"), aTamL2_VLRITEM[1],nDecimais)
					cNSerieRG   := SL2->L2_NSERIE
					nRG++
					AADD(aRelGer, {cCodProdRG,cDescPrdRG,cVlrItemRG,cNSerieRG})
					AADD(aRelGar, {})				
				ElseIf SB1->B1_TIPO = cMvLjTGar 
					cCodProdRG	:= SL2->L2_PRODUTO
					cDescPrdRG	:= SL2->L2_DESCRI
					cVlrItemRG	:= Str(a410Arred(SL2->L2_VRUNIT * SL2->L2_QUANT,"L2_VLRITEM"), aTamL2_VLRITEM[1],nDecimais)
					nRA++
					If nRA == Len(aRelGar)
						aRelGar[nRA] := {cCodProdRG,cDescPrdRG,cVlrItemRG,cNSerieRG}
					EndIf	
				EndIf
			EndIf

			//Desconsidera item de "servico" na impressao do Cupom Fiscal, caso esteja ativa a implementacao de venda com itens de "produto" e itens de "servico"
			If lMVLJPRDSV .And. If(lFunTesISS, LjIsTesISS(SL1->L1_NUM,SL2->L2_TES), SL2->L2_VALISS > 0) //Item de "servico"
				nVlrServic += SL2->L2_VLRITEM //Acumula o valor dos itens de "servico"
				SL2->(DbSkip())
				Loop
			EndIf
			
			If SL2->L2_VALIPI > 0
				lExistIPI := .T.
			EndIf

			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Inicializa a variavel de Icms Solid   ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ			
			nVlrIcmsRet	:= 0
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Carrega o array aVlrAcres com valor igual a zero             ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ			
			If Len( aVlrAcres ) < nItem
 				aAdd(aVlrAcres,0)			
			EndIf

			// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
			If lMVLJPDVPA
				SET DELETE ON
			EndIf
			
			SB1->(DbSeek(xFilial("SB1")+SL2->L2_PRODUTO))
			
			SB0->(DbSeek(xFilial("SB0")+SB1->B1_COD))
		
			SF4->(DbSeek(xFilial("SF4")+SL2->L2_TES))
						
			aLjExcecao := MaFisRet(nItem,"IT_EXCECAO")
			lExcecaoFcl:= Len(aLjExcecao) > 0
			LjGrvLog( M->LQ_NUM , " TES " + AllTrim(SF4->F4_CODIGO) + " - Verificação de exceção fiscal ", aLjExcecao)
			LExecPE7017:= .F.
			
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Verifica a situacao tributaria do item                       ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If cPaisLoc <> "BRA"
				aImps    := TesImpInf(SF4->F4_CODIGO)
				nValImp  := 0
				If nItem <= Len(aContCols)
					For nI := 1 to Len(aImps)
						cIndImp     := Substr(aImps[nI][2],10,1)
						cCampoVal   := "IT_VALIV" + cIndImp
						cCampoAlq   := "IT_ALIQIV" + cIndImp
						If aImps[nI][3] == "1"
					  		nValImp += Round(MaFisRet(aContCols[nItem],cCampoVal),nDecimais)
						EndIf
					Next nI
				EndIf
				If Len(aImps) > 0 .AND. nItem <= Len(aContCols)
					cSitTrib := " " + Str(MaFisRet(aContCols[nItem],cCampoAlq),5,2)
				Else
					cSitTrib := " "
				EndIf
			Else
				
				If SF4->F4_ISS == "S" .AND. ( ( ( SA1->A1_RECISS == "1" .AND. SuperGetMv("MV_DESCISS",,.F.) ) .OR. ( SA1->A1_RECISS <> "1" ) ) )
					If SB1->B1_ALIQISS > 0
						cSitTrib := "S" + AllTrim (Str( SB1->B1_ALIQISS,5,2 ))
					Else                                                                                                        
						cSitTrib := "S" + AllTrim (Str( SuperGetMv("MV_ALIQISS"),5,2 ))
					EndIf
					
				ElseIf If(lF4MKPSOL,SF4->F4_MKPSOL<>"1",.T.) .And. (SB1->B1_PICMRET > 0 .OR.;
				 		(SB1->B1_PICMENT > 0 .AND. ALLTRIM(SF4->F4_SITTRIB) == "60") .OR.;
				 		(lExcecaoFcl .AND. (aLjExcecao[3] > 0 .OR. aLjExcecao[16] > 0 )) );
						 .AND. SA1->A1_TIPO $ cTpSolCf .AND. SF4->F4_BSICMST <> 100
					cSitTrib := "F"					// Substituicao tributaria (Icms Solidario)					
					
				ElseIf (SF4->F4_BASEICM > 0 .AND. SF4->F4_BASEICM < 100) .Or. ;
					(lExcecaoFcl .AND. (aLjExcecao[14] > 0) .AND. (aLjExcecao[14] < 100))
					
					/* Aberto um ponto de entrada para que o cliente possa utilizar
					a aliquota de redução que cadastrou na tabela SL4 ao invés de
					utilizar a do SB0	*/
					If (ExistBlock("LJ7017") .AND. !lFtvdVer12) .OR. (ExistBlock("FTVD7017") .AND. lFtvdVer12)
						If !lFtvdVer12
							LjGrvLog( M->LQ_NUM, " Antes do PE LJ7017")
							nAliqRed := ExecBlock("LJ7017",.F.,.F.)
							LjGrvLog( M->LQ_NUM, " Retorno do PE LJ7017", nAliqRed)
						ElseIf lFtvdVer12
							LjGrvLog( M->LQ_NUM, " Antes do PE FTVD7017")
							nAliqRed := ExecBlock("FTVD7017",.F.,.F.)
							LjGrvLog( M->LQ_NUM, " Retorno do PE FTVD7017", nAliqRed)
						EndIf

						lExecPE7017 := .T.
					Else
						lExecPE7017 := .F.
					EndIf
					
					If !LExecPE7017 .Or.;
						(LExecPE7017 .And. ((Valtype(nAliqRed) <> "N") .OR. ((nAliqRed <= 0) .Or. (nAliqRed >= 100))))
						
						If LExecPE7017
							LjGrvLog( M->LQ_NUM, " Problema no Ponto de Entrada LJ7017 ou FTVD7017. " +CHR(10)+CHR(13)+;
											" Solução: o retorno do PE deve ser do tipo Numerico ou o " +;
											" seu retorno não está entre 1 e 99"+CHR(10)+CHR(13)+;
											" Revise o Ponto de Entrada! " +CHR(10)+CHR(13)+;
											" Será efetuado a busca padrão nas tabelas SB0 e SF4", nAliqRed)
						EndIf
						
						nAliqRed := SB0->B0_ALIQRED	//Considero a alíquota de redução do cadastro de produtos

						// Caso o campo B0_ALIQRED não estiver preenchido e existir excecao fiscal considera o retorno da MaFisRet
						If nAliqRed <= 0 .AND. aLjExcecao[1] > 0
							LjGrvLog( M->LQ_NUM, "Lj7ImpCF -  Redução de Alíquota não preenchida na campo B0_ALIQRED com isso foi assumido o valor da da exceção fiscal." , nAliqRed) 	
							nAliqRed := aLjExcecao[1]
						EndIf	
						
						If lExcecaoFcl
							LjGrvLog( M->LQ_NUM, " Redução de Alíquota configurada como exceção fiscal [ se campo estiver zerado preencha a redução no campo B0_ALIQRED] " , nAliqRed) 		
						Else
							LjGrvLog( M->LQ_NUM, " Redução de Alíquota configurada pela TES [campo F4_BASEICM - se alíquota estiver zerada preencha a redução no campo B0_ALIQRED] " , nAliqRed)
						EndIf
					EndIf					
					
					cSitTrib := "T" + AllTrim(Str(nAliqRed,5,2))		// Com redução de Icms na Base de Cálculo do Imposto
					
				ElseIf SF4->F4_LFICM == "I"								// Isento
					If ALLTRIM(SF4->F4_SITTRIB) == "41"						
						cSitTrib := "N"
					Else						
						cSitTrib := "I"
					EndIf
					
				ElseIf SF4->F4_LFICM == "N" .OR. SF4->F4_LFICM == "O"	// Não sujeito a ICMS
					cSitTrib := "N"

				Else													// Com ICMS					
					nAliquota := AliqIcms(	"N"	,"S",Iif(!Empty(SL1->L1_TIPOCLI),SL1->L1_TIPOCLI,SA1->A1_TIPO),"I",;     
											NIL	,.T.)
					cSitTrib := "T" + AllTrim(Str(nAliquota,5,2))
				EndIf

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Faz o tratamento do valor do ICMS retido³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If SF4->F4_INCSOL <> "N"
					nVlrIcmsRet		:= SL2->L2_ICMSRET
					nVlrTotIcmsRet	+= SL2->L2_ICMSRET
				EndIf				
			EndIf
			
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³ Trata as variaveis para o registro do item validando         ³ 
			//| a impressao do codigo de barras para venda nao concomitante  ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			If SuperGetMv("MV_CODBAR",,"N") == "S" .AND. !Empty(SB1->B1_CODBAR)
				cCodProd	:= SB1->B1_CODBAR
			Else
				cCodProd	:= SL2->L2_PRODUTO
			EndIf
			
			cQuant		:= StrZero(SL2->L2_QUANT,8,3)
			cUnidMed	:= SB1->B1_UM
			
			If cPaisLoc == "BRA"
				If lLjIcmJr	//  Verifico se devera haver incidencia de ICMS no acrescimo.	
			    	nAcrescimo  += aVlrAcres[nItem]
			    Else
			    	nAcrescimo := 0
			    EndIf
			    
				//Tratamento para produto "Recarga de Celular"
				If ExistFunc("Lj7RCPrdRC")
					lIsRecCel := Lj7RCPrdRC(SL2->L2_PRODUTO) //Verifica se o produto eh "Recarga de Celular"
				EndIf
								
			    If lIsRecCel .Or. (lIsVdRecCP .And. Lj7CP_Prod(SL2->L2_PRODUTO))
					 
			    	//Verifica se o pagamento é referente a operação financeira, caso sim não deve ser incidido o ICMS sobre o juros do financiamento.
			    	If lLjIcmJr //Verifico se devera haver incidencia de ICMS no acrescimo.			    		
						cVrUnit := Str(A410Arred(((((SL2->L2_VRUNIT * SL2->L2_QUANT) + SL2->L2_VALDESC + SL2->L2_DESCPRO - aVlrAcres[nItem])) / SL2->L2_QUANT), "L2_VRUNIT"),aTamL2_VRUNIT[1],nDecimais)																		                                                                          												
					Else
						cVrUnit := Str(A410Arred(((((SL2->L2_VRUNIT * SL2->L2_QUANT) + SL2->L2_VALDESC + SL2->L2_DESCPRO)) / SL2->L2_QUANT), "L2_VRUNIT"),aTamL2_VRUNIT[1],nDecimais)																														
					EndIf
					
					cDesconto := Str(SL2->L2_VALDESC,aTamL2_VALDESC[1],aTamL2_VALDESC[2])							
					cVlrItem  := Str(A410Arred((Val(cVrUnit) * SL2->L2_QUANT), "L2_VLRITEM"), aTamL2_VLRITEM[1],nDecimais)										
				Else
				     Lj701DVECF(@cDesconto,@cVrUnit,@cVlrItem )
				EndIf	
				
				nVlrTotIPI	+= SL2->L2_VALIPI				

			Else
				cDesconto	:= Str(SL2->L2_VALDESC,aTamL2_VALDESC[1],aTamL2_VALDESC[2])
				cVrUnit		:= Str((((SL2->L2_VRUNIT * SL2->L2_QUANT)) / SL2->L2_QUANT),aTamL2_VRUNIT[1],nDecimais)
				cVlrItem	:= Str((Val(cVrUnit) * SL2->L2_QUANT) + nValImp,aTamL2_VLRITEM[1],nDecimais)
			EndIf
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Acumula valor do Desconto Proporcional,³
			//³pois pode haver Desconto Financeiro.   ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nDescPro += SL2->L2_DESCPRO
			
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Acumula o Desconto de ICMS a ser deduzido³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nDescICMS += MaFisRet(nItem,"IT_DEDICM")
			
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Acumula o Valor do FECP                  ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			nValFECP += MaFisRet(nItem,"IT_VALFECP")			
			
			/*tratamento para descrição*/
			cDescriProd	:= SL2->L2_DESCRI
			
			/* Ponto de entrada para tratamento das informacoes a serem 
			 enviadas para o ECF  */
			If lFtvdVer12
				If lFTVD7013
					LjGrvLog( NIL, " Antes da execução do P.E. FTVD7013",{cCodProd, cDescriProd, cQuant, cVrUnit, cDesconto, cSitTrib, cVlrItem })
					aRetFTVD7013 := ExecBlock("FTVD7013",.F.,.F.,{cCodProd, cDescriProd, cQuant, cVrUnit, cDesconto, cSitTrib, cVlrItem })
					LjGrvLog( NIL, " Depois da execução do P.E. FTVD7013",aRetFTVD7013)
					If ValType( aRetFTVD7013 ) == "A"
						aRetLj7013 := aClone(aRetFTVD7013)
					EndIf
				EndIf
			Else
				If lLj7013
					LjGrvLog( NIL, " Antes da execução do P.E. LJ7013",{cCodProd, cDescriProd, cQuant, cVrUnit, cDesconto, cSitTrib, cVlrItem })
					aRetLj7013 := ExecBlock("LJ7013",.F.,.F.,{cCodProd, cDescriProd, cQuant, cVrUnit, cDesconto, cSitTrib, cVlrItem })
					LjGrvLog( NIL, " Depois da execução do P.E. LJ7013",aRetLj7013)					
				EndIf
			EndIf
			
			If lLj7013 .Or. lFTVD7013
				If ValType( aRetLj7013 ) == "A" .AND. Len( aRetLj7013 ) >= 7
					cCodProd 		:= aRetLj7013[1]
					cDescriProd		:= aRetLj7013[2]
					cQuant 			:= aRetLj7013[3]
					cVrUnit			:= aRetLj7013[4]
					cDesconto		:= aRetLj7013[5]
					cSitTrib		:= aRetLj7013[6]
					cVlrItem		:= aRetLj7013[7]
				EndIf
			EndIf

			cDescriProd := LjDscCESCF(cDescriProd,nItem)

			If nPosStTrib > 0
				Aadd(aSitTrib,{SL2->L2_ITEM+SL2->L2_PRODUTO,cSitTrib})			
			EndIf
			
			/* Verifica se item é do tipo retira para realizar a impressão  */
			If lMVLJPDVPA 
				lImpItem := Empty(SL2->L2_ENTREGA) .OR. (SL2->L2_ENTREGA == "2")
			EndIf
			 
			If(SuperGetMv("MV_LJIMPGF",,.F.) .AND. SB1->B1_TIPO == cMvLjTGar)
				lImpItem := .F.	
			EndIf

			If lImpItem .And. lTemItProd
				nValorItem	+=	(Val(cVlrItem)-Val(cDesconto))
			
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³ Imprime o item ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If LJAnalisaLeg(39)[1]
	    			dbSelectArea("SB1")
					SB1->( dbSetOrder(1) )	//B1_FILIAL+B1_COD
	
	 			   	If SB1->(dbSeek(xFilial("SB1") + cCodProd))
	    	  			If !Empty(SB1->B1_CODBAR)
	    	  				cCodProd := SB1->B1_CODBAR
	    	  			EndIf	
	    			EndIf
				EndIf

				nItemImp++
				nRet := IFRegItem( 	nHdlECF	, cCodProd	, cDescriProd	, cQuant	, ;
									cVrUnit	, cDesconto	, cSitTrib		, cVlrItem	, ;
									cUnidMed )
				If !Lj7VerCmd( nRet )
				    aRet[3]:=STR0006 //"Falha em Registrar item"
					Return( aRet )
				EndIf             
			Else
				lTemReserva := .T.
			EndIf
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Identifico se o Orcamento eh de Entrega³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
			lEntrega := ( SL2->L2_ENTREGA == "1" ) 

			If !Empty(SL2->L2_RESERVA) .AND. SL2->L2_ENTREGA <> "2"	// armazena o valor dos itens de reserva
				nValRes += SL2->L2_VLRITEM
			EndIf

			// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
			If lMVLJPDVPA
				SET DELETE OFF
			EndIf

			DbSelectArea("SL2")
			SL2->( DbSkip() )
		End
	EndIf 
Else
	nValorItem := Lj7SomaItem()
   	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ-----¿
   	//³ Chama rotina que ira carregar brindes no aCols , aColsDet e imprimi-los	³
   	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ-----Ù
	If CrdxInt() .AND. lUsaFd
		Lj7ImpBrd()
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
   	//³ Alimenta as variaveis cNumCupom e cNumPDV quando venda concomitante ³
   	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
    cNumCupom	:= cNumeroCup
    cNumPdv		:= cNumeroPDV   
    nDescPro	:= SL1->L1_DESCONT		
  
	DbSelectArea("SL2")
	SL2->( DbSetOrder(1) )	//L2_FILIAL+L2_NUM+L2_ITEM+L2_PRODUTO
	SL2->( DbSeek(xFilial("SL2") + SL1->L1_NUM) )

	While SL2->( !Eof() ) .AND. SL2->L2_FILIAL+SL2->L2_NUM == xFilial("SL2")+SL1->L1_NUM   
   
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Se o produto de vendas estiver amarrado a um ³
		//³produto de garantia                          ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lGE
			// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
			If lMVLJPDVPA
				SET DELETE ON
			EndIf

			SB1->(DbSeek(xFilial("SB1")+SL2->L2_PRODUTO))

			If lMVLJPDVPA
				SET DELETE OFF
			EndIf

	   		If  !Empty(SL2->L2_GARANT) .AND. lNumGar
				cCodProdRG	:= SL2->L2_PRODUTO
				cDescPrdRG	:= SL2->L2_DESCRI
				cVlrItemRG	:= Str(a410Arred(SL2->L2_VRUNIT * SL2->L2_QUANT,"L2_VLRITEM"), aTamL2_VLRITEM[1],nDecimais)
				cNSerieRG   := SL2->L2_NSERIE
				nRG++
				AADD(aRelGer, {cCodProdRG,cDescPrdRG,cVlrItemRG,cNSerieRG})
				AADD(aRelGar, {})				
			ElseIf SB1->B1_TIPO = cMvLjTGar 
				cCodProdRG	:= SL2->L2_PRODUTO
				cDescPrdRG	:= SL2->L2_DESCRI
				cVlrItemRG	:= Str(a410Arred(SL2->L2_VRUNIT * SL2->L2_QUANT,"L2_VLRITEM"), aTamL2_VLRITEM[1],nDecimais)
				nRA++
				If nRA == Len(aRelGar)
					aRelGar[nRA] := {cCodProdRG,cDescPrdRG,cVlrItemRG,cNSerieRG}
				EndIf	
			EndIf
		EndIf   
		Sl2->(DbSkip())
	End	   
   
   
EndIf

If lMVLJPDVPA 	// Regra do PAF-ECF para imprimir itens cancelados para venda nao concomitante
	SET DELETE ON
EndIf

If ! SuperGetMv("MV_LJREST",,.F.)	//Variavel utilizada no sistema de restaurante

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se ha acrescimo e/ou desconto.                      ³
	//³ O valor do acrescimo para Brasil, foi acumulado durante a im-³
	//³ pressao dos itens do Cupom.                                  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

	If cPaisLoc == "BRA"
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Soma dos Descontos Proporcionais dos itens pois pode haver desconto Financeiro³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Verifica se é venda concomitante³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lVAssConc
	        For nI := 1 to Len(aVlrAcres)
				nAcrescimo	+=  aVlrAcres[nI]
		   	Next nI
		EndIf	

		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³Acrescimo sobre valor financiado³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If lCalcFin
			nAcrescimo := nVlrAcrsFi
		EndIf
		// Se houver Reserva e se for PdvPaf deve assim proporcionalizar o Acrescimo.
		nAcrescimo	+= IIf ( lMVLJPDVPA .And. nFatorRes < 1 , Round((Lj7CalcFrete() * nFatorVen),2), Lj7CalcFrete(!lMVLJPDVPA) )
		
		//Se o valor do parametro MV_LJTPDES <> 2, o sistema ja adicionou o ICMS Solidario ao valor unitario
		If nMvljTpdes == 2
			nAcrescimo	+= nVlrTotIcmsRet	// Acrescentamos o valor do ICMS Solidario
		EndIf
		// Se houver Reserva e se for PdvPaf deve assim proporcionalizar o Desconto.
		nDesconto 	:= IIf ( lMVLJPDVPA .And. nFatorRes < 1 , Round((nDescPro + nDescICMS) * nFatorVen,2), nDescPro + nDescICMS )
		
		If lExistIPI
			nAcrescimo	+= nVlrTotIPI
		EndIf
	Else
		nDesconto	:= SL1->L1_DESCONT
		nAcrescimo  := ( Lj7T_Subtotal(2) - Lj7T_Total(2) )
	EndIf

	lAcrs := (nAcrescimo > nDesconto)
	
	If lAcrs	
		If nDesconto > 0
			nAcrescimo -= nDesconto
		EndIf   
		If nAcrescimo > 0
			//Aqui foi substituida a chamada da função LJ7CORRIPI() para lExistIPI pois tendo IPI nao se faz necessaria a verificacao feita na funcao
			If nValRes == 0 .AND. Alltrim(Upper(SL1->L1_CONDPG)) == "CN" .AND. !lExistIPI .AND. !(nFatorRes < 1 .AND. !lMVLJPDVPA)
				//se possui ICMS Solidario, o acrescimo referente ao item esta embutido no subtotal da venda,
				// portanto o acrescimo calculado abaixo sera invalido
				If nVlrTotIcmsRet == 0
					nAcrescimo := Lj7T_Total(2) - Lj7T_SubTotal(2) - Lj7T_Troco(2)
				EndIf
			EndIf
			If lTemItProd .And. !lIsVendaVP .And. !lIsVdRecCP
				nRet := IFAcresTot( nHdlECF, AllTrim(Str(nAcrescimo,10,2)) )
				If !Lj7VerCmd( nRet )
				   	aRet[3]:=STR0007 //"Falha no Acrescimo do Total"
					Return ( aRet )
				EndIf
			EndIf
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Retorna o valor de nAcrescimo para o valor original	³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nDesconto > 0
			nAcrescimo += nDesconto
		EndIf
	Else     
		If nAcrescimo > 0
			nDesconto -= nAcrescimo
		EndIf
		If (nDesconto > 0 .AND. !LjAnalisaLeg(22)[1]) .OR. (nDesconto > 0 .AND. LjAnalisaLeg(22)[1] .AND. !lVAssConc)
			If lTemItProd .And. !lIsVendaVP .And. !lIsVdRecCP
				If nValRes > 0
					nRet := IFDescTot( nHdlECF, AllTrim(Str(nDesconto,10,2)) )
				Else
					nRet := IFDescTot( nHdlECF, AllTrim(Str(nDesconto,10,2)) )
				EndIf
				If !Lj7VerCmd( nRet )
				    aRet[3]:=STR0008 //"Falha no Desconto do Total"
					Return ( aRet )
				EndIf
			EndIf
		EndIf
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Retorna o valor de nDesconto para o valor original	³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If nAcrescimo > 0
			nDesconto += nAcrescimo
		EndIf
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Define as formas de pagamentos                                   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nTPCompNCC == 4 .AND. nNCCUsada > (  nValorItem + nAcrescimo - nDesconto)
		cFormaPgtos := Lj7DefForm( nNCCUsada )	
	Else
		cFormaPgtos := Lj7DefForm( 	nValorItem , nAcrescimo, nDesconto, Nil 	,;
									Nil		   , nFatorRes , nFatorVen, nValRes,;
									aTaxJuros  , nVlrServic, nVlrGar)  
	EndIf
		
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Envia as formas de pagamento para o ECF                          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se emite cupom vinculado ou nao.   ³
	//³ Especifico para impressora Urano versao 3.00³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lUsaTef .AND. lTefOk .AND. aScan(aFormaAux,{ |x| AllTrim(x[1]) $ _FORMATEF + "CH;MH" }) <> 0 .AND. ;
		cTipTEF $ TEF_SEMCLIENT_DEDICADO + ";" + TEF_COMCLIENT_DEDICADO + ";" + TEF_DISCADO + ";" + TEF_CLISITEF
		cVinculado := '1'
	EndIf
	If lTemItProd .And. !lIsVendaVP .And. !lIsVdRecCP
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Emite os pagamentos ao ECF ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		lTentarNovamente := .T.
		While lTentarNovamente 

			If nFatorVen <> 1 .AND. nFatorRes <> 1 // Tratamento apenas para vendas mistas ( cupom e entrega )
				// Tratamento realizado para ajustar as formas de pg do sistema com o valor q ta no ECF
				aSubPgto 	:= StrToKarr(cFormaPgtos ,"|")          		// Array com as formas q vao para o ecf
				nSubTPag	:= 0
	
				For nX := 1 To Len(aSubPgto)
					nSubTPag += Val(aSubPgto[nX]) 							// Soma as formas de pagamento que vao para ecf
				Next nX
	
				IFStatus(nHdlECF, "42", @cRet)								// Captura o Subtotal da impressora
				nDifPag := Val(SubStr(cRet,1,len(cRet)-2)+"."+SubStr(cRet,len(cRet)-1))
			EndiF

			If nDifPag > 0 .And. nSubTPag > 0 // Subtotal da impressora (pois algumas nao retornam o comando)
				nDifPag := nDifPag - nSubTPag							// Calcula a diff entre ecf e sistema

				If lMvTroco //Soma o troco, pois o ECF retorna o subtotal liquido e o nosso eh bruto
					nTroco	:= IIf (nModulo == 12, Lj7T_Troco(2),0)
					nDifPag := nDifPag + nTroco
				EndIf

				If nDifPag <> 0 .AND. Abs(nDifPag) < 0.05 // Mais de 5 centavos foge do intuito da funcao e nao deve ajustar
					LjGrvLog(SL1->L1_NUM,"Diferenca no pagamento",nDifPag)

					If nDifPag > 0
						If Len(aSubPgto) > 1 .And. Val(aSubPgto[2]) > 0
							aSubPgto[2] := Str(Val(aSubPgto[2]) + Abs(nDifPag)) // Vai sempre jogar a diff na primeira forma
						EndIf
					ElseIf nDifPag < 0
						If Len(aSubPgto) > 1 .And. Val(aSubPgto[2]) > 0
							aSubPgto[2] := Str(Val(aSubPgto[2]) - Abs(nDifPag)) // Vai sempre jogar a diff na primeira forma
						EndIf
					EndIf
					cFormaPgtos := ""                                   // Refaz a string para enviar p/ ecf
					For nX := 1 To Len(aSubPgto)
						cFormaPgtos += Alltrim(aSubPgto[nX])+"|"		// Preenche a string com as formas de pagamento
					Next
				EndIf
			EndIf

			nRet := IFPagto( nHdlECF, cFormaPgtos, cVinculado, NIL, NIL, NIL, If(cPaisLoc <> "BRA", aImpsSL1, NIL) )
			LjGrvLog(SL1->L1_NUM, "Valores enviados no pagamento",cFormaPgtos)
			lTentarNovamente := nRet <> 0 .AND. MsgYesNo(STR0071) // "Problema com a impressão do pagamento. Tentar novamente?"
		End 
		
		If !Lj7VerCmd( nRet )       
			aRet[3]:=STR0010 //"Falha no registro de pagamento"
			Return ( aRet )
		EndIf                          
	EndIf
	
	If lUsaTef .AND. cTipTef == TEF_CLISITEF .AND. lCartao
		If oTef:CupomReduz()
			If !Empty(oTef:cCupomRedu)
				cMensagem := oTef:cCupomRedu + CHR(10)
			EndIf
		EndIf
	EndIf	
	
	/*
	HOMOLOGACAO PAF-ECF 2013
	 a Ordem das Mensagens Impressas deve ser:
	 1 - MD5 ; 2 - Msg do TPL PCL ou DAV/PRE-VENDA XXXXX ; 3 - Msgs dos Estados (Minas Legal, etc.)
	 4 - Msg da Lei dos Impostos ; 5 - mensagens adicionais
	*/	
	If lPafEcf
		If lNumOrc .AND. !Empty(Alltrim(SL1->L1_NUMORC))  			
			If lPreVenda
		    	cMensagem += STR0063 + SL1->L1_NUMORC + " " + Chr(13)+Chr(10) //"PV: "			
			Else
				If SuperGetMV("MV_LJDAVOS",,.F.)
		   			cMensagem += STR0080 + SL1->L1_NUMORC + " " + Chr(13)+Chr(10) //"DAV-OS:"
	   			Else
		   			cMensagem += STR0062 + SL1->L1_NUMORC + " " + Chr(13)+Chr(10) //"DAV: "
	   			EndIf	   			
			EndIf
		EndIf
    Else	
		If SuperGetMV("MV_LJVACC",,.F.)
			If !LJAnalisaLeg(40)[1]
				cMensagem += STR0011 + SL1->L1_NUM + " "  +CRLF//"Orcamento: "
			EndIf
		Else
			If LJAnalisaLeg(35)[1] .AND. !Empty(AllTrim(SL1->L1_NUMORC))  			
				If lNumOrc .And. !Empty(AllTrim(SL1->L1_NUMORC))  			
					If lPreVenda
						cMensagem += STR0060 + SL1->L1_NUMORC + " "  + CRLF//"PreVenda: "
					Else
						cMensagem += STR0011 + SL1->L1_NUMORC + " "  + CRLF//"Orcamento: "
					EndIf		
				EndIf
			Else
				cMensagem += STR0011 + SL1->L1_NUM + " "  +CRLF //"Orcamento: "
			EndIf
		EndIf
	EndIf
	
	//conteudo abaixo deve estar abaixo do MD-5 - Exigencia Homologacao PAF 2013
	If lPafEcf .AND. HasTemplate("PCL")
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³TPL POSTO(REQUISITO XXXVI):Imprimir identificacao da bomba e do bico ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ExistTemplate("TpPclIBomb")
			cAuxRetMsg := T_TpPclIBomb() //A função já passa a quebra de linha portanto nao usar CRLF aqui.   
			cMensagem += IIF(Empty(AllTrim(cAuxRetMsg)),"", cAuxRetMsg) 
		EndIf
	EndIf
	
	//Verifica deve imprimir mensagem "PARAIBA LEGAL"
	cAuxRetMsg	:=	Lj950PBLeg(Lj7T_Total(2),nDecimais,cNumCupom)
	cMensagem	+= IIF(Empty(AllTrim(cAuxRetMsg)),"", cAuxRetMsg)
	
	//Deve imprimir Placa, Kilometragem, etc. após as mensagens dos estados (minas Legal, cupom mania, etc)
	If lPafEcf .AND. HasTemplate("PCL") 
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³TPL POSTO(REQUISITO XXXIV):Possibilitar impressao da placa/quilometragem do veiculo ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If ExistFunc("LjPclIdCar")
			cAuxRetMsg := LjPclIdCar()
			
			//Efetua pesquisa da IE ou RG do cliente para incluir no texto de finalização do cupom
			If !(Select("SA1") > 0)
				DbSelectArea("SA1")
				SA1->(DbSetOrder(3)) //Filial + CPF/CNPJ
				SA1->(DbSeek(xFilial("SA1")+M->LQ_CGCCLI))
			EndIf
			
			If AllTrim(SA1->A1_PESSOA) == "J"
				cMensagem += If( Empty(AllTrim(SA1->A1_INSCR)), "" , "IE: " + AllTrim(SA1->A1_INSCR) + " " )
			Else
				cMensagem += If( Empty(AllTrim(SA1->A1_PFISICA)), "" , "RG: " + AllTrim(SA1->A1_PFISICA) + " ")
			EndIf 
			
			cMensagem += IIF(Empty(AllTrim(cAuxRetMsg)),"", cAuxRetMsg + CRLF)
		EndIf
	EndIf
	
	//prepara impressao da mensagem "de Olho no Imposto"
	If ExistFunc("Lj950ImpNC")
		cMenImpNCM	:=	Lj950ImpNC(nTotVLRNCM,nTotImpNCM,nDecimais,/*lNFCe*/,nTotImpFED,nTotImpEST,nTotImpMUN)
	EndIf

	// Ponto de Entrada para customizar a mensagem de olho no imposto.
	If ExistBlock("LJ7078")
		cMenImpNCM	:= ExecBlock("LJ7078",.F.,.F.,{nTotVLRNCM,nTotImpNCM,nTotImpFED,nTotImpEST,nTotImpMUN})
	EndIf

	cMensagem += cMenImpNCM

	// Impressao da mensagem referente ao FECP
	If ExistFunc("Lj950FECP")
		cAuxRetMsg	:= AllTrim(Lj950FECP(nValFECP))
		If !Empty(cAuxRetMsg)
			cMensagem	+= cAuxRetMsg + Chr(10)
		EndIf
	EndIf
	    
	If !lPafEcf .AND. (LJAnalisaLeg(32)[1] .OR. LJAnalisaLeg(40)[1])
		cMensagem += "PROTHEUS 12" + CRLF
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Verifica se ha mensagem promocional e fecha o cupom              ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If Substr(cMvLjFisMs,1,1)=="&"
		cMvLjFisMs := &(Substr(cMvLjFisMs,2,Len(cMvLjFisMs)))
	EndIf
	
	cAuxRetMsg := AllTrim(cMvLjFisMs)
	cMensagem += IIF(Empty(AllTrim(cAuxRetMsg)),"", cAuxRetMsg + CRLF)
	
	If Empty(cMvLJFisMs)
		cAuxRetMsg	:= AllTrim(SLG->LG_MSGCUP)
		cMensagem	+= IIF(Empty(AllTrim(cAuxRetMsg)),"", cAuxRetMsg + CRLF)
	EndIf 
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Fecha o cupom e imprime a mensagem promocional  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !Empty( cMsgResg )
		cMensagem := cMensagem + cMsgResg
	EndIf      
	/*
	 Verifica se a empresa pertece ao regime de arrecadacao do Simples Nacional
	*/
	If lLjSimpNac
		cMensagem := STR0059 + CRLF + cMensagem   //"ICMS a ser recolhido conforme LC 123/2006 - Simples Nacional"
	EndIf

	If lTemItProd .And. !lIsVendaVP .And. !lIsVdRecCP
		
		//Caso o ECF tenha a impressão do cliente na finalização do cupom deve-se enviar os dados
		//não valida o LjAnalisaLeg pois esta configuração e parametrizavel 
		If !lVAssConc
			aRetInfDocCli	:= {}			
			If Lj950ImpCpf(Lj7T_Total(2)) .Or. (LjInfDocCli() > 1)
				aRetInfDocCli := LjxDCGC(Nil,Nil,@lImpCpfNpj,@cMensagem,Lj7T_Total(2)) 
				cCpfCli := aRetInfDocCli[1]
			EndIf
			
			If 	Len(aRetInfDocCli) > 0 .And.;
			 	!(Empty(aRetInfDocCli[1]) .And. Empty(aRetInfDocCli[2]) .And. Empty(aRetInfDocCli[3])) 		
				nRet := IFIdCliente(nHdlECF , @lImpCpfNpj , aRetInfDocCli)
			EndIf
		EndIf
		
		If !Empty(AllTrim(cNumNotaCF)) //Variavel preenchida somente em homologação do PAF
			cMensagem := "NF:"+cNumNotaCF+CHR(10) + cMensagem
		EndIf
			
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Fecha o cupom fiscal ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		lTentarNovamente := .T.
		While lTentarNovamente 
			nRet := IFFechaCup( nHdlECF, cMensagem, lImpCpfNpj )
			lTentarNovamente := nRet <> 0 .AND. MsgYesNo(STR0072) // "Problema com o fechamento do cupom fiscal. Tentar novamente?"
			
			/*Gravo o campo como sinalizar de cupom OK, pois se o sistema cair depois 
			desse ponto o cupom fiscal não era cancelado na abertura do sistema*/
			If nRet == 0 .And. SL1->(ColumnPos("L1_NUMCFIS")) > 0
				aAreaSL1 := SL1->(GetArea())
				RecLock("SL1",.F.)
				REPLACE L1_NUMCFIS WITH cNumCupom
				SL1->(MsUnlock())
				RestArea(aAreaSL1)
			EndIf
		End
		
		If !Lj7VerCmd( nRet )
			aRet[3]:=STR0012 //"Falha no fechamento do cupom"
			Return ( aRet )
		EndIf
	EndIf
Else
	If ExistFunc("LjRestImp")    
		aRet := LjRestImp(	aRet,			@nRet,			@nHdlECF,		@cNumCupom, 		;
							@cNumPdv,		@cSitTrib, 		@cTpSolCf,		@nAliqRed,			; 
							@nVlrIcmsRet,	@nVlrTotIcmsRet,@cCodProd,		@cDescriProd,		;	
							@cQuant,		@cVrUnit,		@cDesconto,		@cVlrItem,			;
	        				@cUnidMed, 		@nAcrescimo, 	@lAcrs,			@cMensagem,			;
	        				@cFormaPgtos,	@aFormaAux,		@cMvLjFisMs,	@aPgtos,			;		
	        				@lUsaRegime,	@lUsaCartao,	@cVinculado,	@lUsaTef,			;
	        				@lTefOk,		@cTipTEF,		@aTamL2_VRUNIT,	@aTamL2_VALDESC,	;		
							@aTamL2_VLRITEM,@cDinheiro      )
	    
		If nRet <> 0
			Return aRet	
		EndIf
    EndIf
EndIf	

If lSFinanc .AND. Len(aRelSF)>0 .AND. ExistFunc(cImpRGer)
	For nCont:=1 To Len(aRelSF)
		If  cImpRGer == SuperGetMV("MV_RELGART",,"U_LOJR600A")

			cRet := chr(16) + &cImpRGer.(aRelSF[nCont][1],aRelSF[nCont][2],aRelSF[nCont][3],aRelSF[nCont][4],;
	    		                          aRelSF[nCont][5],aRelSF[nCont][6],aRelSF[nCont][7],SA1->A1_NOME,nMoedaCor,.T.)
       
		Else 
			cRet := chr(16) + &cImpRGer.(SL1->L1_NUM, Nil)
		EndIf
	Next nCont 
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Chama a função que fará a impressão do relatorio gerencial ³
//³caso contenha produtos vendidos com garantia estendida     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If  lGE .AND. nRG <> 0 .AND. ExistFunc(cImpRGer) .AND. nRA >= nRG
	DbSelectArea("SL2")
	SL2->(DbSetOrder (1))        					//Filial + Orçamento + Item + Produto
	If SL2->(DbSeek(xFilial("SL2")+SL1->L1_NUM))
		For nCont:=1 To nRG
			If Len(aRelGer) >= nRG				 
				cRet := chr(16) + &cImpRGer.(aRelGer[nCont][1],aRelGer[nCont][2],aRelGer[nCont][3],aRelGer[nCont][4],;
		    		                          aRelGar[nCont][1],aRelGar[nCont][2],aRelGar[nCont][3],SA1->A1_NOME,nMoedaCor)
	 		EndIf
		Next nCont 
	EndIf
	If	ExistFunc("LjxGetRGer")
		LjxSetRGer()
		LjxSetRGar() 
	EndIf
	
ElseIf lGE .AND. ExistFunc(cImpRGer) .AND. nRA >= nRG  .AND. ExistFunc("LjxGetRGer")
	
	// Faz a impressao quando a venda nao tem item fiscal associado
	aRelGer := LjxGetRGer()
	aRelGar := LjxGetRGar() 
	 
	If Len(aRelGer) > 0 .AND. Len(aRelGer) == Len(aRelGar)
		For nCont :=1 To Len(aRelGer)
			cRet := chr(16) + &cImpRGer.(	aRelGer[nCont][1]	,aRelGer[nCont][2]	,aRelGer[nCont][3]	,aRelGer[nCont][4] 		,;
	        								aRelGar[nCont][1]	,aRelGar[nCont][2]	,aRelGar[nCont][3]	,SA1->A1_NOME,nMoedaCor	)
		Next nCont 
	EndIf	
	
	aRelGer := {}
 	aRelGar := {}
 	 
	LjxSetRGer()
	LjxSetRGar()  
	
EndIf 

If Val(GetVersao(.F.)) >= 12
	L701DCVTImp( nHdlECF, cNumCupom )
EndIf

Lj7RestArea( aArea )

aRet := { lRet , {cNumCupom,cNumPdv},'' }

Return aRet

//-------------------------------------------------------------------
/*{Protheus.doc} L701DCVTImp
Faz a impressao do cupom de vale troca

@author Varejo
@since 18/08/2011
@version 1.0
*/
//-------------------------------------------------------------------
Function L701DCVTImp( nHdlECF, cNumCupom,lNFiscal )
Local aArea       := GetArea()              // Salva a area corrente
Local cCupomTroca := ""                     // Codigo do cupom de troca
Local cSerie      := PadR(LjGetStation("SERIE"),TamSX3("L1_SERIE")[1])	// Serie da impressora
Local cSerieCVT   := ""                     // Serie codificada que sera impressa no cupom de troca
Local nCount      := 1                      // Contador
Local nX          := 0                      // Contador
Local aCVTs       := {}                     // Array contendo os codigos de barras que serao impressos no Cupom de Vale Troca
Local cCabecalho  := ""															// Cabeçalho da impressão
Local cRodape     := ""															// Rodapé da impressão
Local cTexto      := ""

Default lNfiscal  := .F.
Default nHdlECF   := 0
Default cNumCupom := ""

cRodape := CRLF
cRodape += "Orçamento         : "+SL1->L1_NUM+CRLF
cRodape += "Cliente           : "+SL1->L1_CLIENTE+"/"+SL1->L1_LOJA+CRLF 
cRodape += "Nome do Cliente   : "+Posicione("SA1",1,xFilial("SA1")+SL1->L1_CLIENTE+SL1->L1_LOJA,"SA1->A1_NOME")+CRLF
cRodape += "Vendedor          : "+SL1->L1_VEND+CRLF
cRodape += "Nome do Vendedor  : "+Posicione("SA3",1,xFilial("SA3")+SL1->L1_VEND,"A3_NOME")+CRLF

While nCount <= Len(cSerie)
	
	If IsDigit(SubStr(cSerie,nCount,1))
		cSerieCVT += "0"+SubStr(cSerie,nCount,1)
	ElseIf Empty(SubStr(cSerie,nCount,1))
		cSerieCVT += "99"
	Else
		cSerieCVT += AllTrim(Str(ASC(SubStr(cSerie,nCount,1))))
	EndIf
	
	nCount++
End

cCupomTroca := Alltrim(cNumCupom)+cSerieCVT

DbSelectArea("SL2")
SL2->(DbSetOrder())

If DbSeek(xFilial("SL2")+SL1->L1_NUM)
	While xFilial("SL1")+SL1->L1_NUM == xFilial("SL2")+SL2->L2_NUM
		
		If SL2->L2_VLTROCA == "1"
			For nX := 1 To SL2->L2_QUANT
				cCabecalho := "     C U P O M  D E  T R O C A"+CRLF+CRLF
				cCabecalho += "Item   : "+SL2->L2_ITEM+CRLF
				cCabecalho += "Código : "+SL2->L2_PRODUTO+CRLF
				cCabecalho += "Produto: "+SL2->L2_DESCRI+CRLF
				cTexto += CRLF+CRLF + cCabecalho 				 
				Aadd(aCVTs,{cCabecalho,cCupomTroca+SL2->L2_ITEM})
			Next nX
		EndIf
		SL2->(DbSkip())
	End
EndIf

If lNFiscal
	cTexto := cTexto + cRodape
	cTexto += TAG_COD128_INI + Replicate("0",6)+cCupomTroca + TAG_COD128_FIM
	//Realiza a impressao nao fiscal.
	INFTexto(cTexto)
	INFTexto(TAG_GUIL_INI+TAG_GUIL_FIM)
Else 
	For nX := 1 To Len( aCVTs )
		IFCodBar( nHdlECF, aCVTs[nX,1], Replicate("0",6)+aCVTs[nX,2], cRodape ,1)
	Next nX
EndIf

RestArea( aArea )

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ImpCNF ºAutor  ³Vendas Clientes     º Data ³  24/09/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a impressao do "pedido" (orcamento com reserva)         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := LJ7ImpCNF()                                        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpA1 - Array contendo:                                     º±±
±±º          ³        [1] - .T. / .F. Se conseguiu completar a impressao  º±±
±±º          ³        ou teve algum erro                                  º±±
±±º          ³        [2] - Array contendo:                               º±±
±±º          ³              Se a 1a posicao for .T.:                      º±±
±±º          ³              [2][1] - Numero do cupom                      º±±
±±º          ³              [2][2] - Numero do PDV                        º±±
±±º          ³              Se a 1a posicao for .F.:                      º±±
±±º          ³              [2][1] - Codigo do Erro                       º±±
±±º          ³              [2][2] - Descricao do Erro                    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÌÍÍÍÍÍÍÍÍÑÍÏÍÍÍÍÑÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß 
*/
Function LJ7ImpCNF( lTefOk	, nFatorRes	, lAbrecup	,	cOrcam	,;
					nTotCF	, nMoedaAtu	, nOpcao	, aItProdGar,;
					aReserva, nVlrPagCF	, nVlrTefCF	, nVlrNccCF,;
					lVendMis, nCupTEf	, cTxtNFis ) 

Local aRet			:= 	{ .F., {"",""} }				// Retorno da funcao
Local sTef			:= "N"								// Indica ser depois da impressao do cupom do "Pedido" ira imprimir o TEF
Local cRetorno		:= Space(10)						// Variavel para pegar o status do ECF na funcao IFStatus()
Local cCondPgTEF	:= ""								// Define a forma de pagamento que sera utilizada para abrir o recebimento para fazer o cupom vinculado do TEF
Local lFunImp		:= .F.								// Se a funcao da impressora eh 01 no LojxEcf
Local lVerHora		:= .T.								// Se a hora eh para verificar a hora, dependendo do retorno do LojxEcf
Local nValSemTef	:= 0								// Valor Total - Valor pago em TEF
Local lNfAltDoc     := LjNfAltDoc(SM0->M0_CGC)		    // Se alterar Documento entre Cupom e Nota Fiscal
Local lAutoExD		:= IsBlind()						// Verifica se a rotina sera executada via execauto ou nao
Local lContinua 		:= .T.								// Variavel para controlar se continua ou aborta a execucao desta funcao
Local lMacroPed		:= .F.                              // Verifica se existe macro execução para o número do pedido
Local cMV_LOJAPED	:= AllTrim(SuperGetMv("MV_LOJAPED",,"PED")) // Serie do Pedido
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local lVendDireta   := Iif(lFtvdVer12,.T., .F.)                              // Indica que foi acionada pela rotina Venda Direta. 
Local lEmitNfce		:= LjEmitNFCe()									//Sinaliza se utiliza NFC-e

DEFAULT nFatorRes 	:= 1
DEFAULT lAbrecup	:= .T.
DEFAULT cOrcam		:= ""
DEFAULT nTotCF		:= 0
DEFAULT nMoedaAtu	:= 1   
DEFAULT nOpcao 		:= 1 //Opcao de operacao [1=Pedido; 2=RPS (Recibo Provisorio de Servico); 3=Comprovante do Vale Presente; 4=Comprovante de Recarga do Cartao Presente GIFT CARD]
DEFAULT aItProdGar	:= {}                               // Array de Garantia Estendida
DEFAULT aReserva	:= {}
DEFAULT nVlrPagCF	:= 0  
DEFAULT nVlrTefCF	:= 0 
DEFAULT nVlrNccCF 	:= 0
DEFAULT lVendMis	:= .F.
DEFAULT nCupTEf		:= 0
DEFAULT cTxtNFis 	:= ""

If lFtvdVer12 
	lMacroPed	:=	IIf(Substr(cMV_LOJAPED, 1 , 1) == "&",.T.,.F.)
EndIf

//³Ve se a venda foi em TEF³
DbSelectArea("SL1")
DbSetOrder(1)
If SL1->L1_VENDTEF == "S" .OR. lTefOK
	sTef := "S"
	//³ Verifica a forma de pagamento do comprovante TEF             ³
	cFormaPgtos := Lj7DefForm( nTotCF	, Nil	,Nil   ,@nValSemTef ,;
							   nMoedaAtu )
	cCondPgTEF 	:= StrToKArr( cFormaPgtos, "|" )[1] 
EndIf

If lNfAltDoc .AND. !LjNFFimVd()  // Verifica se pode alterar Nota Fiscal ao Finalizar(lNfAltDoc) e Se pode emitir NotaFiscal (LjNFFimVd() == .T.)
	lNfAltDoc	:=	.F.
EndIf

If !lEmitNfce .AND. !lFtvdVer12 .AND. !lNfAltDoc .AND. !lAutoExD
	//³ Verifica a data da impressora, nao permite a impressao se a  ³
	//³ data do ECF for diferente da data do sistema                 ³
	If LjEcfIFData( @lFunImp, @lVerHora )
		If !lFunImp 	    
			If !VerifHora()
			    Return( aRet )
			EndIf
		Else
			If !lVerHora
				Return( aRet )
			EndIf		
		EndIf
	EndIf	
	//³ Verifica se ha um cupom em aberto. Caso afirmativo, faz o    ³
	//³ cancelamento antes da abertura de outro                      ³
	If cPaisLoc == "BRA" .OR. (cPaisLoc <> "BRA" .AND. lFiscal)
		nRet := IFStatus( nHdlECF, '5', @cRetorno )
		If nRet == 7
			nRet := IFCancCup( nHdlECF )
			If Lj7VerCmd( nRet )
				Inkey(8) //³ dá um tempo para a impressora fazer a impressao do cancelamento³  
			Else
				Return ( aRet )
			EndIf
		EndIf
	EndIf
EndIf

If nOpcao == 1 //1=Pedido
	If !ExistBlock("SCRPED")
		If !lAutoExD
			MsgStop(STR0016) //"O rdmake SCRPED.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Else
			Conout(STR0016) //"O rdmake SCRPED.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Endif
		lContinua := .F.
	EndIf
ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
	If !ExistBlock("SCRRPS")
		If !lAutoExD
			MsgStop(STR0074) //"O rdmake SCRRPS.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Else
			ConOut(STR0074) //"O rdmake SCRRPS.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Endif
		lContinua := .F.
	EndIf
ElseIf nOpcao == 3 //3=Comprovante do Vale Presente
	If !ExistBlock("SCRVPres")
		If !lAutoExD
			MsgStop(STR0082) //"O rdmake SCRVP.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Else
			ConOut(STR0082) //"O rdmake SCRVP.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Endif
		lContinua := .F.
	EndIf
ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
	If !ExistBlock("SCRCGift")
		If !lAutoExD
			MsgStop(STR0086) //"O rdmake SCRCGift.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Else
			ConOut(STR0086) //"O rdmake SCRCGift.PRW não está compilado e não será possível imprimir o comprovante de venda. Informe essa mensagem ao administrador do sistema."
		Endif
		lContinua := .F.
	EndIf
EndIf
//³Define o tipo de impressão para diferentes tipos de chamada.³
If lContinua
	//³Utilizar impressora fiscal	 ³
	If (cPaisLoc == "BRA" .AND. !lEmitNfce .AND. !lFtvdVer12 .AND. !lNfAltDoc .AND. !lAutoExD) .OR.;
		(cPaisLoc <> "BRA" .AND. lFiscal)
	     aRet:= LjPrtFis(  nFatorRes , nValSemTef , sTef	 , lAbrecup ,;
	                      cCondPgTEF, @cRetorno	 , nOpcao, lVendDireta, ;
	                      aItProdGar, aReserva, nVlrPagCF,nVlrTefCF,;
	                      nVlrNccCF, nCupTEf)
	//³Utilizar impressora nao fiscal ³
	Else 
	    aRet:= LjPrtNFis( nOpcao , lVendDireta, aItProdGar, @cTxtNFis, nFatorRes, nVlrNccCF )
	EndIf
EndIf

Return aRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjPrtFis  ºAutor  ³João Paulo          º Data ³  09/06/11   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Utilizacao de Impressora Fiscal/ECF                         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³LjPrtFis()				                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 									                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³AxpL1 - Retorna array com valor da cupom fiscal e serie     º±±
±±º          ³     													      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701D                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjPrtFis(	nFatorRes	, nValSemTef, sTef		, lAbrecup	 	,;
					cCondPgTEF	, cRetorno	, nOpcao	, lVendDireta	,;
					aItProdGar 	, aReserva	, nVlrPagCF	, nVlrTefCF		,;
					nVlrNccCF	, nCupTEf	) 
					
Local cNumCupom 	:= Space(TamSX3("L1_DOC")[1])    	// Armazena o numero do cupom 
Local cNumPdv 		:= Space(TamSX3("L1_PDV")[1])    	// Armazena o numero do PDV
Local cTexto		:= ""								// Texto com o cupom nao fiscal que será enviado para o ECF
Local cValor		:= ""								// Valor do cupom que será enviado para o ECF
Local lRelGer		:= .F.								// Variável que controla se foi impresso um relatório gerencial ou um comprovante não-fiscal
Local nTamSX3Doc	:= TamSx3("L1_DOC")[1]				// tamando so l1_doc
Local nRet			:= 0
Local aRet			:= { .F., {"", ""} }   
Local nValDescGar	:= 0 								// valor que a garantia representa no Desconto total  
Local nValAcresGar	:= 0 								// valor que a garantia representa no Acrescimo total
Local nX			:= 0   
Local lGE          	:= ExistFunc("LjUP104OK") .AND. LjUP104ok(.T.)     			    // Indica se o release e 11.5  
Local nI 			:= 0 								//variavel de looping
Local lTCheque		:= .F.		// Indica se foi pago com TEF  
Local lMTef			:= .F.		// Indica se tem mais de 1 forma de pagamento TEF  
Local cFormaCR 		:= ""
Local cTotNFisCR 	:= ""
Local nCredito 		:= 0
Local lUsaTotNCC 	:= .F. //Indica se imprime Totalizador Nao Fiscal Separado para o Valor de NCC utilizada no pagamento
Local nFrete		:= 0
local nCrediTot		:= SL1->L1_CREDITO
  
Default nFatorRes	:= 0
Default nValSemTef  := 0
Default sTef        := "N"
Default lAbrecup	:= .T.
Default cCondPgTEF  := ""
Default cRetorno    := ""
Default nOpcao 		:= 1 //Opcao de operacao [1=Pedido; 2=RPS (Recibo Provisorio de Servico); 3=Comprovante do Vale Presente; 4=Comprovante de Recarga do Cartao Presente GIFT CARD]
Default lVendDireta := .F.                          	// Indica que foi acionada pela rotina Venda Direta (FTVDImpCNF).
Default aItProdGar	:= {}                               // Array de Garantia Estendida
Default areserva	:= {}                               // Array de Garantia Estendida
Default nVlrPagCF 	:= 0
Default nVlrTefCF	:= 0
Default nVlrNccCF 	:= 0
Default nCupTEf		:= 0

lUsaTotNCC	:= !Empty( GetPvProfString("TOTALIZADORES", "ComprovanteCredito", "", GetClientDir() + "SIGALOJA.INI") ) .And. nOpcao == 1 .And. SL1->L1_CREDITO > 0 //1=Pedido
nFrete		:= IIf(nFatorRes < 1 , Lj7CalcFrete(),Lj7CalcFrete(!lMVLJPDVPA)) 

//Tratamento quando utilizar NCC
//Imprime um Comprovante Nao Fiscal separado com o valor proporcional da NCC do Pedido (Venda Entrega Futura)
If lUsaTotNCC
	nCredito := nCrediTot - nVlrNccCF
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se ha um cupom em aberto e se eh venda com $ de item nao fiscal ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !(Funname() $ "FRTA271") .And. nModulo == 12
	lAbrecup := nFatorRes <> 1  
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Monta o Texto³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nOpcao == 1 //1=Pedido
	cTexto := ExecBlock( "SCRPED", .F., .F., {aItProdGar, nFatorRes,(nCrediTot - nVlrNccCF)} )
ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
	cTexto := ExecBlock("SCRRPS", .F., .F. )
ElseIf nOpcao == 3 //3=Comprovante do Vale Presente]
	cTexto := ExecBlock("SCRVPres", .F., .F. )
ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
	cTexto := ExecBlock("SCRCGift", .F., .F. )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Ajusta o valor³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Funname() $ "FRTA271/FRTA010"
	If lGe
		For nx :=1 to Len(aItProdGar)
			nValDescGar += aItProdGar[nx][5]
			nValAcresGar+= aItProdGar[nx][6]
		Next nx
		
		If Len(aReserva) <> Len(aItProdGar) // se houver produtos e garantia com reserva, nao soma o desconto , pois não foi descontado anteriormente
			nValDescGar  := 0
			nValAcresGar := 0 
		EndIf
	EndIf
	If nOpcao ==3 //adicionando valor para vale presente
		cValor 		:= Str(SL1->L1_VLRLIQ,15,2)
	Elseif nFatorRes == 1 																				 	// Todos os itens da venda estao em reserva
		If (nCredito == SL1->L1_VLRLIQ .Or. nCredito > SL1->L1_VLRLIQ)								// Caso a venda seja paga integralmente com Ncc
			cValor 		:= Str(0,15,2)
		Else
			cValor 		:= Str(((SL1->L1_VLRLIQ*nFatorRes)-(nVlrPagCF+nVlrTefCF)) ,15,2)
		EndIf 
	Elseif (nFatorRes < 1) .And. (nCrediTot == SL1->L1_VLRLIQ .Or. nCrediTot > SL1->L1_VLRLIQ)   // Caso a venda seja paga integralmente com Ncc
		cValor 		:= Str(0,15,2)	
	ElseIf (nFatorRes < 1) .And. (nCredito > 0) 													 	// Caso a venda seja paga parcialmente com Ncc			
		cValor 		:= Str(((SL1->L1_VLRLIQ) * nFatorRes)-(nCredito+nCupTEf),15,2)         
	Else		
		cValor 		:= Str(((SL1->L1_VLRLIQ*nFatorRes) + nValDescGar - nValAcresGar)- nCupTEf ,15,2) 
	EndIf	
	nValSemTef	+= SL1->L1_CREDITO
Else
	If lVendDireta
		cValor 		:= Str((SL1->L1_VLRLIQ + SL1->L1_CREDITO ),15,2)
	Else
		cValor 		:= Str((SL1->L1_VLRLIQ * nFatorRes) + (nFrete*nFatorRes),15,2)
	EndIf 		
	nValSemTef	+= SL1->L1_CREDITO
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³	 Proteção para Telecheque	  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ 
If Type("oTef") != "U".And. ValType(oTef:aDados) == "A"	
	lMTef := (Len(oTef:aDados) > 1)  // Indica que teve mais de uma forma TEF

	For nI := 1 to Len(oTef:aDados)	
		If oTef:Adados[nI][3] == "CH"
			lTCheque := .T.  
			Exit
		EndIf
	Next
EndIf


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Troca as virgulas do cTexto pois esse caracter eh utilizado como separador³
//³ dos parametro na ExecInClient                                             ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cTexto := StrTran( cTexto, ',', '.' )
			                  	                  
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Chama a funcao de impressao do comprovante de venda (pedido) ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If (UPPER(sTef) == "S" .AND. !lAbrecup) .AND. !LjAnalisaLeg(25)[1] .AND. nValSemTef > 0 .And. !lTCheque  
   //Cupom nao fiscal
   nRet := IfPedido( nHdlECF, "N", cTexto, STR(nValSemTef), cCondPgTEF )

ElseIf (UPPER(sTef) == "S" .AND. !lAbrecup) .OR. LjAnalisaLeg(25)[1] .OR. Val(cValor) == 0
	//Relatorio gerencial
	nRet := IfRelger( nHdlECF, cTexto, 1 )
	lRelGer := .T.
ElseIf (UPPER(sTef) != "S" .AND. !lAbrecup) .OR. (UPPER(sTef) != "S" .AND. lAbrecup)
	//Cupom nao fiscal
	nRet := IfPedido( nHdlECF, sTef, cTexto, cValor, cCondPgTEF )
ElseIf (UPPER(sTef) == "S" .AND. lAbrecup) .And. Val(cValor) > 0
	//Cupom nao fiscal
	nRet := IfPedido( nHdlECF, "N", cTexto, cValor, cCondPgTEF )
Else 		
	//Relatorio gerencial
	nRet := IfRelger( nHdlECF, cTexto, 1 )
	lRelGer := .T.
EndIf

//Tratamento quando utilizar NCC
//Imprime um Comprovante Nao Fiscal separado com o valor proporcional da NCC do Pedido (Venda Entrega Futura)
If lUsaTotNCC .And. nCredito > 0 
	//Imprime Comprovante de Credito (NCC)
	cFormaCR := AllTrim(Tabela("24","CR",.F.))
	cTotNFisCR := GetPvProfString("TOTALIZADORES", "ComprovanteCredito", "RECEBIMENTOS", GetClientDir() + "SIGALOJA.INI")
	nRet := IFRecebNFis ( nHdlECF, cTotNFisCR, nCredito 		 , cFormaCR  )
EndIf

If nRet==0
	aRet := { .T., {"", ""} }

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Pega o numero do Comprovante Nao Fiscal                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If cPaisLoc <> "ARG"
		nRet := IFPegCupom( nHdlECF, @cNumCupom )
	Else
		nRet := IFStatus( nHdlECF, '17', @cRetorno )
		cNumCupom:=SubStr(cRetorno,13,(nTamSX3Doc - 4))
		cNumCupom:=StrZero(Val(cNumCupom)+1,Len(AllTrim(cNumCupom)) ,0)
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Se a impressão do comprovante não foi um relatório gerencial, então pode-se alterar                  ³
	//³a variável cNumCupom. Sem esta validação, poderá causar um erro de chave duplicada no Banco de Dados,³
	//³pois o número título financeiro poderá se repetir.                                                   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If !lRelGer .OR. Val(cValor) == 0
		If (cPaisLoc <> "ARG" .And. cPaisLoc <> "BOL" .And. cPaisLoc <> "MEX") 
			cNumCupom:=StrZero(Val(cNumCupom)-1,Len(AllTrim(cNumCupom)) ,0)
		EndIf
	EndIf
	
	If lVendDireta
		If !FTVDVerCmd( nRet )
			If Type("lAutoExec") <> "L" .OR. !lAutoExec	.OR. nOpcao == 1 //1=Pedido	
				MsgStop(STR0013) //"Erro ao pegar o número do cupom após a impressão do pedido. Verifique o ECF."
			ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
				MsgStop(STR0075) //"Erro ao pegar o número do cupom após a impressão do RPS (Recibo Provisório de Serviço). Verifique o ECF."
			ElseIf nOpcao == 3 //3=Comprovante do Vale Presente]
				MsgStop(STR0083) //"Erro ao pegar o número do cupom após a impressão do Comprovante do Vale Presente. Verifique o ECF."
			ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
				MsgStop(STR0087) //"Erro ao pegar o número do cupom após a impressão do Comprovante de Recarga do Cartão Presente. Verifique o ECF."
			EndIf
			aRet := { .F., {"", ""} }
			Return( aRet )
		EndIf 
	ElseIf !Lj7VerCmd( nRet ) 
		If nOpcao == 1 //1=Pedido
			MsgStop(STR0013) //"Erro ao pegar o número do cupom após a impressão do pedido. Verifique o ECF."
		ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
			MsgStop(STR0075) //"Erro ao pegar o número do cupom após a impressão do RPS (Recibo Provisório de Serviço). Verifique o ECF."
		ElseIf nOpcao == 3 //3=Comprovante do Vale Presente]
			MsgStop(STR0083) //"Erro ao pegar o número do cupom após a impressão do Comprovante do Vale Presente. Verifique o ECF."
		ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
			MsgStop(STR0087) //"Erro ao pegar o número do cupom após a impressão do Comprovante de Recarga do Cartão Presente. Verifique o ECF."
		EndIf
		aRet := { .F., {"", ""} }
		Return( aRet )
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Pega o numero do PDV                                         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nRet := IFPegPDV( nHdlECF, @cNumPdv )
	If lVendDireta
		If !FTVDVerCmd( nRet )
			If Type("lAutoExec") <> "L" .OR. !lAutoExec .OR. nOpcao == 1 //1=Pedido	
				MsgStop(STR0014) //"Erro ao pegar o número do PDV após a impressão do pedido. Verifique o ECF."
			ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
				MsgStop(STR0076) //"Erro ao pegar o número do PDV após a impressão do RPS (Recibo Provisório de Serviço). Verifique o ECF."
			ElseIf nOpcao == 3 //3=Comprovante do Vale Presente]
				MsgStop(STR0084) //"Erro ao pegar o número do PDV após a impressão do Comprovante do Vale Presente. Verifique o ECF."
			ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
				MsgStop(STR0088) //"Erro ao pegar o número do PDV após a impressão do Comprovante de Recarga do Cartão Presente. Verifique o ECF."
			EndIf
			aRet := { .F., {"", ""} }
			Return( aRet )
		EndIf 
	ElseIf !Lj7VerCmd( nRet )
		If nOpcao == 1 //1=Pedido
			MsgStop(STR0014) //"Erro ao pegar o número do PDV após a impressão do pedido. Verifique o ECF."
		ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
			MsgStop(STR0076) //"Erro ao pegar o número do PDV após a impressão do RPS (Recibo Provisório de Serviço). Verifique o ECF."
		ElseIf nOpcao == 3 //3=Comprovante do Vale Presente]
			MsgStop(STR0084) //"Erro ao pegar o número do PDV após a impressão do Comprovante do Vale Presente. Verifique o ECF."
		ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
			MsgStop(STR0088) //"Erro ao pegar o número do PDV após a impressão do Comprovante de Recarga do Cartão Presente. Verifique o ECF."
		EndIf
		aRet := { .F., {"", ""} }
		Return( aRet )
	EndIf
	aRet := { .T. , {cNumCupom,cNumPdv} }
Else

	If nOpcao == 1 //1=Pedido
		MsgStop(STR0015) //"Erro na impressão do pedido. Verifique o ECF"
	ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
		MsgStop(STR0077) //"Erro na impressão do RPS (Recibo Provisório de Serviço). Verifique o ECF"
	ElseIf nOpcao == 3 //3=Comprovante do Vale Presente
		MsgStop(STR0085) //"Erro na impressão do Comprovante do Vale Presente. Verifique o ECF"
	ElseIf nOpcao == 4 //4=Comprovante de Recarga do Cartao Presente GIFT CARD
		MsgStop(STR0089) //"Erro na impressão do Comprovante de Recarga do Cartão Presente. Verifique o ECF"
	EndIf	
EndIf

Return aRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LjPrtNFis ºAutor  ³João Paulo          º Data ³  09/06/11   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Utilizacao de Impressora nao Fiscal                         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³LjPrtNFis()				                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ 									                          º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³AxpL1 - Retorna array com valor da cupom não fiscal e serie º±±
±±º          ³     													      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701D                                                    º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LjPrtNFis( nOpcao , lVendDireta, aItProdGar, cTxtNFis, nFatorRes, nVlrNccCF )

Local aRet			:= {.F.,'',''}          	// Arrray de retorno
Local aNumPed       := {} 						// Array que armazenará o número do pedido
Local aTamL1SerPed	:= TamSX3("L1_SERPED")		// Tamanho do campo L1_SERPED
Local nTamL1_DOCPED := TamSX3("L1_DOCPED")[1] 	// Tamanho do campo L1_DOCPED
Local nTent         := 0						// Tentativas para pegar o numero do "pedido" do SXE/SXF
Local cSerie 		:= ""               		//Variavel de retorno para serie do pedido de venda
Local aAreaSL1      := {}						// Variavel para salvar a area do SL1
Local nRet			:= 0
Local lMacroPed		:= .F.                              // Verifica se existe macro execução para o número do pedido
Local cMV_TPNRNFS	:= LjTpNrNFS()						// Retorno do parametro MV_TPNRNFS, utilizado pela Sx5NumNota() de onde serah controlado o numero da NF  1=SX5  2=SXE/SXF  3=SD9
Local cMV_LOJAPED	:= AllTrim(SuperGetMv("MV_LOJAPED",,"PED")) // Serie do Pedido
Local xRet												//Retorno da macro execução do parametro MV_LOJAPED
/*Release 11.5 - Controle de Formularios
	Paises: Chile/Colombia             */
Local lCFolChiR5	:= SuperGetMv("MV_CTRLFOL",.F.,.F.) .AND. cPaisLoc$"CHI|COL" .AND. !lFiscal

Local lEmitNfce		:= LjEmitNFCe() 	//Sinaliza se utiliza NFC-e
Local cTexto		:= ""												//Texto com o cupom nao fiscal que será enviado para equipamento nao fiscal
local nCrediTot		:= SL1->L1_CREDITO
Local aAreaSE1		:= {}
Local cFilSE1		:= xFilial("SE1")

Default nOpcao 		:= 1 //Opcao de operacao [1=Pedido; 2=RPS (Recibo Provisorio de Servico); 3=Comprovante do Vale Presente; 4=Comprovante de Recarga do Cartao Presente GIFT CARD]
Default lVendDireta := .F.                          	// Indica que foi acionada pela rotina Venda Direta (FTVDImpCNF).
Default cTxtNFis	:= ""
Default nFatorRes 	:= 0
Default nVlrNccCF 	:= 0

If nOpcao == 1 .OR. nOpcao == 3	

	If nOpcao == 1	// 1 = Pedido
		//
		// Foi necessário para que não ocorra erro na função Lj010Nota
		//
		If cPaisLoc == "ARG"
			cSerie := LjxDSerArg()
		Else
			lMacroPed := IIf(Substr(cMV_LOJAPED, 1 , 1) == "&",.T.,.F.)
	
			If lMacroPed
	
				xRet := &( SubStr(cMV_LOJAPED,2,Len(cMV_LOJAPED)) )
	
				If ValType(xRet) == "A"
					aNumPed	:=	xRet	// O Retorno deste array deve ser: {cMvSerie, cNumNota}
					cSerie	:=	IIf( ValType(aNumPed[1][1]) == "C", aNumPed[1][1], "PED" )
					aRet := { .T. , {aNumPed[1][2],Space(nTamL1_DOCPED),aNumPed[1][1]} } 
				ElseIf ValType(xRet) == "C"
					cSerie	:=	xRet
				EndIf
			Else
				If lEmitNFCe .AND. SLG->(ColumnPos("LG_SERNFIS")) > 0 .And. !Empty(LjGetStation("SERNFIS"))
					cSerie	:=	LjGetStation("SERNFIS") //Pega a Serie Nao Fiscal configurada no PDV (LG_SERNFIS)
				Else
					cSerie	:=	cMV_LOJAPED  	//Preencha a variável com o número de série que está no MV_LOJAPED
				EndIf
			EndIf
		EndIf
	
	ElseIf nOpcao == 3	 //3 = Vale Presente	

		If lEmitNFCe .AND. SLG->(ColumnPos("LG_SERNFIS")) > 0
			cSerie	:= LjGetStation("SERNFIS")
		EndIf

	EndIf

	//
	// Se variavel estiver nula carrega com o tamanho do campo
	//
	If Empty(cSerie)
		cSerie := Space( aTamL1SerPed[01])
	Else
		cSerie := PadR(cSerie, aTamL1SerPed[01])
	EndIf
	
	cNumNota := Space(nTamL1_DOCPED)
	
	//
	// Gera o número do pedido com base na série ou permite que o usuário selecione consumidor final.                                                            ³
	//
	If !lMacroPed 
	
		If !LjxDNota(cSerie,3,.F.,1,@aNumPed) 
	   		aRet := { .F., {} } 
			Return(aRet) 
		EndIf
		
		//
		// Foi necessário para que não ocorra erro na função quando for SD9
		//				
		If Len(aNumPed) == 0 .And. cMV_TPNRNFS == "3"
			aAdd( aNumPed, { cSerie,  MA461NumNf( .T., cSerie ) } )
		Endif						
		
		aAreaSL1 := SL1->( GetArea() )
		DbSelectArea("SL1")		
		SL1->( DbSetOrder(11) )	//L1_FILIAL + L1_SERPED + L1_DOCPED

		cMay := AllTrim(xFilial("SL1"))+cSerie+aNumPed[01][02]
		FreeUsedCode()	
				
		//Realiza a validação da SE1
		If nOpcao == 3
		
			aAreaSE1 := SE1->(GetArea())

			DbSelectArea("SE1")
			SE1->( DbSetOrder(1) )		//E1_FILIAL + E1_PREFIXO + E1_NUM + E1_PARCELA + E1_TIPO
			
			While  SE1->( DbSeek(cFilSE1 + cSerie + aNumPed[01][02]) )  .OR.;
				   SL1->( DbSeek(xFilial("SL1") + cSerie + aNumPed[01][02]) ) .OR. ;
				   !MayIUseCode(cMay)
				If ++nTent > 20
					//Verifica se eh digito numerico
					If Type("lAutoExec") <> "L" .OR. !lAutoExec		
						MsgStop(STR0040)//"Nao foi possivel gerar o numero do pedido corretamente."
					Else
						Conout(STR0040) //"Nao foi possivel gerar o numero do pedido corretamente."
					EndIf
					aRet := { .F., {} }
					RestArea(aAreaSE1)
					RestArea(aAreaSL1)
					Return(aRet)
				EndIf
				FreeUsedCode()
				aNumPed       := {} 
				If !LjxDNota(cSerie,3,.F.,1,@aNumPed) 
					If Type("lAutoExec") <> "L" .OR. !lAutoExec		
						MsgStop(STR0040)//"Nao foi possivel gerar o numero do pedido corretamente."
					Else
						Conout(STR0040) //"Nao foi possivel gerar o numero do pedido corretamente."
					EndIf
	   				aRet := { .F., {} } 
					RestArea(aAreaSE1)
					RestArea(aAreaSL1)
					Return(aRet) 
				EndIf

				//
				// Foi necessário para que não ocorra erro na função quando for SD9
				//				
				If Len(aNumPed) == 0 .And. cMV_TPNRNFS == "3"
					aAdd( aNumPed, { cSerie,  MA461NumNf( .T., cSerie ) } )
				Endif	
				cMay := AllTrim(xFilial("SL1"))+cSerie+aNumPed[01][02]
			EndDo

			//Restaura ambiente
			RestArea(aAreaSE1)
		
		Else
		
			nTent := 0
			While SL1->( DbSeek(xFilial("SL1") + cSerie + aNumPed[01][02]) ) .OR. !MayIUseCode(cMay)
				If ++nTent > 20
					If Type("lAutoExec") <> "L" .OR. !lAutoExec		
						MsgStop(STR0040)//"Nao foi possivel gerar o numero do pedido corretamente."
					Else
						Conout(STR0040) //"Nao foi possivel gerar o numero do pedido corretamente."
					EndIf
					aRet := { .F., {} }
					Return(aRet) 
				EndIf
				FreeUsedCode()
				aNumPed[01][02] := StrZero(Val(aNumPed[01][02])+1,nTamL1_DOCPED)              
				cMay := AllTrim(xFilial("SL1"))+cSerie+aNumPed[01][02]
			End
	
		EndIf
		

		RestArea(aAreaSL1)
			
		//
		// Quando se trata de um usuário não fiscal o PE não retorna nenhum valor, simplesmente emite o relatório
		//
		If lVendDireta .OR. (!cPaisLoc $ "CHI|COL" )
			// 1 - PEDIDO
			If nOpcao == 1				
				ExecBlock("SCRPED", .F., .F., {aItProdGar,nFatorRes,(nCrediTot - nVlrNccCF)} )
			// 3 - VALE PRESENTE
			ElseIf nOpcao == 3			
				ExecBlock("SCRVPres", .F., .F. )
			EndIf
		EndIf
			
		aRet := { .T. , {aNumPed[1][2],Space(nTamL1_DOCPED),aNumPed[1][1]} } 
		
	EndIf
EndIf	                    

//Impressão do comprovante similiar ao emitido no ECF em equipamento não fiscal
If aRet[1] .AND. lEmitNfce .Or. (nOpcao == 2 .And. lEmitNfce)

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Monta o Texto³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nOpcao == 1		//1=Pedido
		cTexto := ExecBlock( "SCRPED", .F., .F., {aItProdGar, nFatorRes,(nCrediTot - nVlrNccCF),aNumPed} )
	ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
		cTexto := ExecBlock( "SCRRPS", .F., .F. )
	ElseIf nOpcao == 3	//3=Vale Presente
		cTexto := ExecBlock( "SCRVPRES", .F., .F. )	
	EndIf

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Troca as virgulas do cTexto pois esse caracter eh utilizado como separador³
	//³ dos parametro na ExecInClient                                             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	cTexto := StrTran( cTexto, ',', '.' )			         
	
	If SuperGetMV("MV_FTTEFGU",, .T.)	// Ativa guilhotina
		cTexto += TAG_PULANL_INI+" "+TAG_PULANL_FIM+TAG_GUIL_INI+TAG_GUIL_FIM
	EndIf
	         	                  

	cTxtNFis := "==============================================="+ CRLF + ;
				"============ C O M P R O V A N T E ============"+ CRLF + ;
				"==============================================="+ CRLF + ;
				cTexto 
	
	//Tratamento para imprimir apenas depois da impressao do TEF na funcao Lj7Pedido, caso seja SIGALOJA on-line
	//Somente imprime o comprovante nao fiscal neste ponto, caso nao seja pedido ou nao seja modulo SIGALOJA ou seja Paf-ECF
	If nOpcao <> 1 .Or. nModulo <> 12 .Or. lMVLJPDVPA .Or. !Empty(aItProdGar)
		nRet := INFTexto(cTxtNFis)  //Envia comando para a Impressora
		cTxtNFis := "" //Limpa variavel caso ja seja realizada a impressao neste ponto
		If nRet <> 0 .And. SuperGetMV("MV_NFCEIMP",, 1) == 2 //Impressao do comprovante nao fiscal da venda: 1=Opcional; 2=Obrigatorio; (para poder concluir a venda)
			aRet[1] := .F. //Nao permite finalizar a venda, pois nao conseguiu imprimir o comprovante do Pedido
		EndIf
	EndIf
	
	If nRet <> 0

		If nOpcao == 1 //1=Pedido
			MsgStop(STR0015) //"Erro na impressão do pedido. Verifique o ECF"
		ElseIf nOpcao == 2 //2=RPS (Recibo Provisorio de Servico)
			MsgStop(STR0077) //"Erro na impressão do RPS (Recibo Provisório de Serviço). Verifique o ECF"
		EndIf	
	
	EndIf	

EndIf

Return aRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7VerCmd ºAutor  ³Vendas Clientes     º Data ³  18/08/02   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se ouve erro no ECF                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpL1 := Lj7VerCmd( ExpN1 )                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpN1 - Codigo de retorno do ECF                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpL1 - Se houve erro (.F. - para parar a rotina)           º±±
±±º          ³        ou nao (.T. - para continuar a rotina)              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7VerCmd( nRet )
Local lRet := .T.

If nRet <> 0
	lRet := .F.
EndIf

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7LogCF  ºAutor  ³Vendas Clientes     º Data ³  24/10/03   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Log atraves de arquivo TXT, para avaliar os pontos de con   º±±
±±º          ³controle de geracao do cupom fiscal indevido                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Function LJ7Logcf(cTipo,cNumPdv,cNumCupom,cChave,nRec,aLoja)º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cTipo - Ponto de gravacao, sendo 'A': Ponto do sistema, aposº±± 
±±º          ³        gravacao dos dados da loja LOJA701C.PRW             º±±
±±º          ³                                 'B': Ponto do sistema, aposº±± 
±±º          ³        Impressao do cupom de pedido LOJA701C.PRW           º±±
±±º          ³cNumPdv   - Numero do PDV                                   º±±
±±º          ³cNumCupom - Numero do cupom fiscal                          º±±
±±º          ³cChave    - Chave da tabela utilizada                       º±±
±±º          ³nRec      - Numero do registo                               º±±
±±º          ³aLoja     - Array com os dados das lojas a serem gerado os  º±±
±±º          ³            orcamentos                                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ .T.                           							  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7Logcf( cTipo, cNumPdv, cNumCupom, cChave,;
				   nRec , aLoja )
				   
Local cExt    := xNumCaixa()			// Caixa atual
Local nHandle := -1						// nHandle
Local cImpArq := Space(10)				// Tamanho do arquivo
Local nI      := 0       				// Contador de For

Default cTipo := ''

If !GetNewPar("MV_LOGCF",.T.)
   Return .T.
EndIf
cImpArq := Repli("-",80) + chr(13) + chr(10)
cImpArq += STR0017 + DToC(Date()) + chr(13) + chr(10) //"Data        :"
cImpArq += STR0018 + Time() + chr(13) + chr(10)       //"Hora        :"
If ctipo="A"
	cImpArq += STR0019 + aLoja[1] +chr(13) + chr(10) //"Filial do orcamento original (pedido)          :"
	cImpArq += STR0020 + aLoja[2] +chr(13) + chr(10) //"Numero do orcamento original (pedido)          :"
	cImpArq += STR0021 + aLoja[3] +chr(13) + chr(10) //"Codigo da loja da reserva (SLJ)                :"
	cImpArq += STR0022 + aLoja[4] +chr(13) + chr(10) //"Codigo da filial da reserva                    :"
	cImpArq += STR0023 + chr(13)  +chr(10)          //"Array com os itens do SL2 de cada loja (filial):"
    For nI := 1 to Len(aLoja[5])
		cImpArq += STR0024 + aLoja[5][nI] + chr(13)+chr(10) //"Item :"
	Next nI		
	cImpArq += STR0025 + aLoja[6] + chr(13) + chr(10) //"Quebra para entrega                            :"
Else
	cImpArq := Repli(".",80) 							+ chr(13) + chr(10)
	cImpArq += STR0026 + cNumPdv 						+ chr(13) + chr(10) 	//"PDV         :"
	cImpArq += STR0027 + cNumCupom 						+ chr(13) + chr(10)    //"Cupom Fiscal:"
	cImpArq += STR0028 + xFilial("SL1") + SL1->L1_NUM 	+ chr(13) + chr(10)  	//"Chave    SL1:"
	cImpArq += STR0029 + Str(SL1->(RECNO()),9) 		+ chr(13) + chr(10)    	//"Registro SL1:"
	cImpArq += STR0030 + cChave 						+ chr(13) + chr(10)    	//"Chave    SL2:"
	cImpArq += STR0031 + Str(nRec,9) 					+ chr(13) + chr(10)    	//"Registro SL2:"
EndIf       
For nI := 1 To 20
	cImpArq += STR0032 + StrZero(nI,2)+") :"+ProcName(nI)+STR0033+Str(ProcLine(nI))+chr(13)+chr(10) //"Chamada("###" Linha :"
Next nI
If File("LOGCF."+cExt)            
    nI := 0
	While nHandle < 0 .AND. nI <=5
	    nI++
		nHandle	:= FOpen("LOGCF."+cExt,2)
		Inkey(1)
	End
	FSeek(nHandle,0,2)
Else
	nHandle := FCreate("LOGCF."+cExt)
EndIf
FWrite( nHandle, cImpArq )
FClose( nHandle )
Return .T.

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ImpCFArºAutor  ³Vendas Clientes     º Data ³  26/01/03   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Faz a impressao do cupom fiscal (Localizaçoes Argentina)    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³Lj7ImpCFArg(aTaxJuros,aDadosCF)                      		  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³ExpA1 := Taxa de juros da administradora                    º±±
±±ºParametro ³ExpA2 := Dados do Consumidor Final	                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³Loja701                                                     º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ImpCFArg(aTaxJuros,aDadosCF)
Local cA1TIPO		:= ""
Local cProduto		:= ""
Local cVend			:= SL1->L1_VEND
Local cCond			:= SL1->L1_CONDPG
Local cCgc			:= ""
Local cTipoID		:= ""
Local cImps1		:= ""
Local cImps2		:= ""
Local cUnit			:= ""
Local cValDescIt	:= ""
Local cQuant		:= ""
Local cTmpHas		:= ""
Local cRetorno		:= ""
Local cLinVend		:= ""
Local cLinCond		:= ""
Local cLinCliente	:= ""
Local cDescProd		:= ""
Local cMensagem		:= ""  
Local cTotAcrs		:= ""
Local cDescTotal	:= ""
Local cIncluiIVA	:= "B"  //Se T indica que o preco contem IVA incluido. Se B, o IVA eh discriminado
Local nQuant		:= 0
Local nAliq			:= 0
Local nAliqIVA		:= 0
Local nX			:= 0
Local nPosHas		:= 0
Local nVlrUnit		:= 0
Local nImp			:= 0
Local nVlrTot		:= SL1->L1_VLRTOT
Local cVlrItem		:= ""
Local cSitTrib		:= ""
Local nTamL1DOC		:= TamSX3("L1_DOC")[1]
Local nRet			:= 1
Local nItem			:= 0
Local aFormPgto		:= {{SuperGetMv("MV_SIMB1")},{"CC"},{"CD"},{"CH"}}
Local cNumPdv		:= ""
Local cNumCup		:= ""
Local nI			:= 0
Local aRet			:= {.F.,'',''}
Local aAreaSL2		:= {}
Local lVAssConc		:= LjVassConc()										// Indica se o cliente utiliza a Venda Assistida Concomitante
Local lFunImp		:= .F.												// Se a funcao da impressora eh 01 no LojxEcf
Local lVerHora		:= .T.												// Se a hora eh para verificar a hora, dependendo do retorno do LojxEcf
Local lLJ7050		:= FindFunction("U_LJ7050")	.AND. cPaisLoc == "ARG" // Verifica se Existe o Ponto de Entrada
Local xRet
Local lImpTick		:= .T.												// Se a impressao sera ticket ou factura
Local xImpTick															// Retorno do PE Lj7050
Local aBkpImpsSl2	:= {}												// Remonta o array com os impostos
Local nImpSegVia	:= SuperGetMV("MV_LJQTTK", ,0)						// Indica se imprime 2ª via.							
Local nY			:= 0												// Variavel de controle de LOOP
Local xOpt			:= 2												// Controle de reimpressao Hasar (Argentina).
Local lImpTicFat	:= SuperGetMv("MV_IMPTIFA", , .F.)					// Indica se a msm impressora imprime ticket e fatura.
Local cMvLjFisMs	:= SuperGetMv("MV_LJFISMS", , "")					// Conteudo da variavel MV_LJFISMS 
Local nDesconto     := 0
Local nQtdAliq      := 0
Local nAliquota     := 0
Local lLj7013		 := ExistBlock("LJ7013",Nil,.T.)			// Ponto de entrada
Local aRetLj7013	:= {}												//Array do ponto de entrada
Local cLogPath		:= "\AUTOCOM\TEF"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")+"\"
Local lRet			:= .T.
Local aLog			:= {}
Local cLinDomici	:= ""												//linha do endereço do cliente
Local nPosVlrItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]	// Posicao da Valor total do item
Local nTotImp		:= 0																		// Valor Total do impostos que somam no item
Local nTotImpInt	:= 0
Local nValAcres		:= 0												//Valor do Acrescimo
Local cUnidMed		:= ""
Local cEndCom1		:= ""
Local cEndCom2		:= ""
Local lAutoExD		:= IsBlind()										// Verifica se a rotina sera executada via execauto ou nao
Local aRetPDV		:= {"",""}
Local nVlrTotIt     := 0                                                // Valor total dos itens. 
Local nVlrItem      := 0                                               	// Valor do item com o impostos ja calculados. 
Local nPercDesIt    := 0                                               	// Percentual de desconto no item.
Local nValDescIt    := 0                                               	// Valor do desconto no item.
Local nTotDescIt    := 0                                                // Valor total de descontos nos itens.
Local nDescTotal    := 0                                                // Valor do desconto no total considerando os impostos.
Local nValDescT		:= 0												//Valor do desconto
Local cTipoCli      := "2"                                              // Tipo do cliente 1 = Cons.Final  2= Resp. Inscripto. 
Local cTipoImp      := ""												// Tipo de impressao do cupom 1-Valores Inclusos ou 2-Valores Discriminados.
Local cEstabl		:= ""
Local nVlrAcrs		:= 0
Local cRetLj7093	:= ""
Local lLj7093		:= ExistBlock("LJ7093")
Local lFTVD7050    	:= ExistBlock("FTVD7050")            				// Verifica se Existe o Ponto de Entrada
Local lLog1    		:= SubStr(FTVDGetProfile("LOGERRO"),1,1) == "S" 	// Tem Log de Erro
Local lLog4        	:= SubStr(FTVDGetProfile("LOGERRO"),4,1) == "S" 	// Log de Recuperacao, grava as parcelas
Local nSize        	:= 0 
Local cRBuffer     	:= ""
Local nValTotIt		:= 0
Local aImpDifIVA	:= {} 												// array contendo os impostos que não somam ao IVA
Local cImpItem		:= '' 												// String com para o envio dos impostos do Item para a impressora
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()											//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida

Default aTaxJuros 	:= {}  
Default aDadosCF 	:= {}

// Deve passar a mensagem aqui pois no caso da Epson TM-U220 a mensagem do final do cupom dever ser passada antes da abertura do mesmo.
If AllTrim(SM0->M0_ESTCOB) == "BA"
	cMensagem := STR0061 + CHR(13) + CHR(10) + cMensagem   //"Orientação ao Consumidor Província de Buenos Aires 0800 222 9042"
EndIf

If cMensagem <> "" 
	cMensagem += "_"
EndIf	

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se ha mensagem promocional e fecha o cupom.³
//³Caracter para quebra de linha '_'                   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Substr(cMvLjFisMs,1,1)=="&"
	cMvLjFisMs := &(Substr(cMvLjFisMs,2,Len(cMvLjFisMs)))
EndIf
   
cMensagem += AllTrim(cMvLjFisMs) 

If cMensagem <> "" 
	cMensagem += "_"
EndIf	

cMensagem += AllTrim(LjGetStation("LG_MSGCUP"))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica se a data do sistema eh a mesma data da impressora fiscal. ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If LjEcfIFData( @lFunImp, @lVerHora )
	If !lFunImp 	    
		If !VerifHora()
			Return ({.F.,aRetPDV,''})
		EndIf
	Else
		If !lVerHora
			Return ({.F.,aRetPDV,''})
		EndIf		
	EndIf
EndIf

cTmpHas     :=  AllTrim(SuperGetMv("MV_IMPSIVA",,"IVA|"))  //Codigo dos impostos que somam no IVA antes do " | " depois no " | " codigo do impostos internos
nPosHas	    :=	AT("|",cTmpHas)

If nPosHas == 0
	nPosHas	:=	Len(cTmpHas)
	cImps1	:=	Substr(cTmpHas,1,nPosHas)		// Sem "|" apenas codigo dos impostos que somam no IVA.
Else
	cImps1	:=	Substr(cTmpHas,1,nPosHas-1)		// Antes do "|" codigo dos impostos que somam no IVA.          
EndIf

cImps2	    :=	Substr(cTmpHas,nPosHas+1)       // Depois do "|" codigo dos impostos internos.

cRetorno := Space(40)
nRet     := IFStatus(nHdlECF, '5', @cRetorno)
If nRet == 1
	Return ({.F.,aRetPDV,''})
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³se exitir cupom aberto, faz o cancelamento e abre um novo.          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nRet = 7
	nRet := IFCancCup( nHdlECF )
	If L010AskImp(.F.,nRet)
		Return ({.F.,aRetPDV,''})
	EndIf
	Inkey(8)   // dá um tempo para a impressora fazer a impressao do cancelamento
EndIf

nRet := IFPegPDV(nHdlECF, @cNumPdv)
aRet := LjStr2Array(cNumPDV)
If nRet == 1
	Return ({.F.,aRetPDV,''})
EndIf
cNumPDV  := aRet[1]

SA3->(DbSetOrder(1))
SA3->(DbSeek( xFilial("SA3") + cVend ))

If SA3->(Found())
	cLinVend  := STR0058 + AllTrim(cVend) + " " + Capital( SA3->(A3_NOME) ) // "Vendedor: "
Else
	cLinVend  := " "
End

SE4->(DbSetOrder(1))
If SE4->(DbSeek( xFilial("SE4") + cCond ))
	cLinCond   := "Cond. de Pago: " + Capital( SE4->(E4_DESCRI) )
Else
	cLinCond   := " "
EndIf

SA1->(DbSetOrder(1))
SA1->(DbSeek( xFilial("SA1") + SL1->L1_CLIENTE + SL1->L1_LOJA ))
Do Case
	Case SA1->A1_TIPO = "X"
		cA1Tipo := "E"    //Isento
	Case SA1->A1_TIPO = "F" .OR. Empty( SA1->A1_TIPO )
		cA1Tipo := "C"   //Consumidor Final
	Case SA1->A1_TIPO = "S"
		cA1Tipo := "A"   //Nao responsavel
	Case SA1->A1_TIPO = "Z"
		cA1Tipo := "I"   //Responsavel Inscrito
	OtherWise
		cA1Tipo := SA1->A1_TIPO
EndCase

If SA1->A1_TIPO == "F"
	cCgc     := SA1->A1_RG
	cTipoID  := "2"   //DNI - Documento Nacional de Identidad
Else
	cCgc     := AllTrim( SA1->A1_CGC )
	cTipoID  := "C"  //CUIT
	If Empty(cCGC)
		If Type("lAutoExec") <> "L" .OR. !lAutoExec		
			MsgAlert(STR0034)    //"O cliente nao tem CUIT cadastrado. Nao sera gerada a nota fiscal. Atualize os dados do cliente!"
		Else
			Conout(STR0034)    //"O cliente nao tem CUIT cadastrado. Nao sera gerada a nota fiscal. Atualize os dados do cliente!"
		EndIf	
		GrabLogHsr(STR0035 + SL1->L1_NUM )   //"O cliente nao tem CUIT cadastrado "
		Return ({.F.,aRetPDV,''})
	EndIf
	If !Cuit(cCGC,"A1_CGC")
		If Type("lAutoExec") <> "L" .OR. !lAutoExec		
			MsgAlert(STR0036)    //"O cliente nao tem CUIT valido cadastrado. Nao sera gerada a nota fiscal. Atualize os dados do cliente!"
		Else
			Conout(STR0036)    //"O cliente nao tem CUIT valido cadastrado. Nao sera gerada a nota fiscal. Atualize os dados do cliente!"
		EndIf				
		GrabLogHsr(STR0037 + SL1->L1_NUM  )   //"O CUIT e invalido "
		Return ({.F.,aRetPDV,''})
	EndIf
EndIf
                                                                              
If Len(aDadosCF) > 0 .And. aDadosCF[1] <> Nil .And. !Empty(aDadosCF[1])

	cLinCliente  :=  Padr(Substr(aDadosCF[4],1,30),30) + ;
					"|" + StrTran( AllTrim(aDadosCF[1]), "-", "0" ) + ;
					"|" + cA1Tipo + ;
					"|" + cTipoID
										                 
	cLinDomici	:= Padr(Substr(aDadosCF[6],1,40),40) + ;
					"|" + SA1->A1_MUN + ;	
					"|" + SA1->A1_EST					
											
Else
	cLinCliente  := Padr(Substr(SA1->A1_NOME,1,30),30) + ;
					"|" + StrTran( AllTrim(cCGC), "-", "" ) + ;
					"|" + cA1Tipo + ;
					"|" + cTipoID

	cLinDomici	:= Padr(Substr(SA1->A1_END,1,40),40) + ;
					"|" + SA1->A1_MUN + ;
					"|" + SA1->A1_EST
Endif					

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Abre o Cupom Fiscal                                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cSerie	:= Lj7SerArg()
cRetorno:= cSerie + "|" + cLinCliente + "|" + cLinVend + "|" + cLinCond
cEndCom1:= Substr(SM0->M0_ENDCOB, 1, 40)
cEndCom2:= Alltrim(Substr(SM0->M0_CIDCOB, 1, 24)) + " - " + Alltrim(Substr(SM0->M0_ESTCOB, 1, 2)) + " - " + Alltrim(Substr(SM0->M0_CEPCOB, 1, 10))

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Ponto de Entrada que permite personalizar  ³
//³os parametros no envio para a impressão .  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lFtvdVer12
	If lFTVD7050
		LjGrvLog( NIL, " Antes da execução do P.E. FTVD7050", {cRetorno, xImpTick })
		xRet  := U_FTVD7050(cRetorno,@xImpTick)
		LjGrvLog( NIL, " Depois da execução do P.E. FTVD7050", xRet )
	EndIf
Else
	If lLJ7050
		LjGrvLog( NIL, " Antes da execução do P.E. LJ7050", {cRetorno, xImpTick, cLinDomici, cEndCom1 , cEndCom2 , cEstabl})
		xRet := U_LJ7050( cRetorno, @xImpTick, @cLinDomici, @cEndCom1 , @cEndCom2 , @cEstabl )
		LjGrvLog( NIL, " Depois da execução do P.E. LJ7050", xRet )
	EndIf
EndIf

If lLJ7050 .Or. lFTVD7050
	If ValType(xRet) == "C"
		cRetorno  := xRet
	EndIf
	
	If ValType(xImpTick) == "L"
		If !xImpTick
			lImpTick := .F.
		EndIf
	EndIf
EndIf

If nVlrTot >= SuperGetMV("MV_LIMFACT",,10000)
	cRetorno += "|S"
	lImpTick := .F.
Else
	cRetorno += "|T"
EndIf

cRetorno += "|" + cLinDomici + "|" + cEndCom1 + "|" + cEndCom2 + "|" + cEstabl

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Tratamento porque os parametros dentro da DLL sigaloja utilizam "," ³
//³entao nao se pode ter "," em nenhum dos parametros enviado.         ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cRetorno := Replace( cRetorno, ",", "&_" )

nRet    := IFAbreCup(nHdlECF, cRetorno, NIL , NIL, NIL, NIL, NIL, cMensagem) 
If nRet == 1
	Return ({.F.,aRetPDV,''})
EndIf

cRetorno   := Space(nTamL1DOC)
nRet       := IFPegCupom( nHdlECF, @cRetorno, "D|"+AllTrim(cSerie))
If nRet == 1
	Return ({.F.,aRetPDV,''})
EndIf

cNumCup := StrZero(Val(cRetorno),nTamL1DOC,0)
cNumCup := cNumPdv + Substr( cNumCup,1+Len(cNumPdv),Len(cNumCup)-Len(cNumPdv) )

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Remonta o array de impostos, caso haja algum itens ³
//³deletado no aCols                                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Len(aImpsSL2) > 0
	aBkpImpsSl2 := aClone(aImpsSL2)
	aImpsSL2 := {}
EndIf

For nX := 1 To Len(aCols) 
	If !aCols[nX][Len(aHeader) + 1]
		Aadd(aImpsSL2, aBkpImpsSl2[nX]) 
	EndIf
Next nX

nValAcres := 0

SE4->(DbSetOrder(1))
SE4->(DbSeek( xFilial("SE4") + cCond ))

DbSelectArea("SL2")
aAreaSL2 := SL2->(GetArea())
SL2->(DbSetOrder(1))
SL2->(DbSeek(xFilial("SL2")+SL1->L1_NUM))
While !(SL2->(Eof())) .AND. SL2->L2_FILIAL+SL2->L2_NUM == xFilial("SL2")+SL1->L1_NUM
	nAliqIVA	:= 0
	nAliq		:= 0
	nTotImp		:= 0
	nTotImpInt	:= 0
	cUnit		:= ""
	cValDescIt	:= ""
	nValDescIt  := 0
	nPercDesIt  := 0 
	nItem++

	// Posiciona produto para pegar a descricao.
	SB1->( DbSetOrder( 1 ) )
	SB1->( DbSeek( xFilial( "SB1" ) + SL2->L2_PRODUTO ) )
	
	SF4->( DbSetOrder( 1 ) )
	SF4->( DbSeek( xFilial( "SF4" ) + SL2->L2_TES ) )

	cProduto	:=	SL2->L2_PRODUTO
	cDescrip    :=	SB1->B1_DESC
	nQuant      :=	SL2->L2_QUANT
	nVlrUnit	:=	SL2->L2_PRCTAB	
	nValDescIt  :=  SL2->L2_VALDESC
	nPercDesIt  :=  SL2->L2_DESC 
	cUnidMed	:=  SB1->B1_UM
	
	cVlrItem	:= Str((nVlrUnit * nQuant),12,4)
	cQuant		:= Str(nQuant,12,3)
	cUnit		:= Str(nVlrUnit,12,4)
	cValDescIt	:= Str(SL2->L2_VALDESC,9,2)	
	
	nValTotIt 	+= Val(cVlrItem) - Val(cValDescIt)
	nValAcres += SL2->L2_VALACRS	
	
	For nImp := 1 To Len(aImpsSL2[nItem][3])		

		If aImpsSL2[nItem][3][nImp][1] $ cImps1 // Verifica se o imposto deve ser somado ao IVA ou nao
			nAliqIVA	:= nAliqIVA + aImpsSL2[nItem][3][nImp][2]
		Else
			Aadd( aImpDifIVA , {aImpsSL2[nItem][3][nImp][1] , aImpsSL2[nItem][3][nImp][2] } )
		EndIf
		
		If Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ cImps1     //Os impostos que soman no IVA	
			nTotImp		:= nTotImp + aImpsSL2[nItem][3][nImp][4]
		ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ cImps2 //Os impostos internos
			nTotImpInt	+= aImpsSL2[nItem][3][nImp][4]/nQuant
			nAliq		:= nAliq + aImpsSL2[nItem][3][nImp][2]
			nTotImp		:= nTotImp + aImpsSL2[nItem][3][nImp][4]
		Else
			nTotImp		:= nTotImp + aImpsSL2[nItem][3][nImp][4]
		EndIf
	Next nImp

	LjGrvLog( "LOJA701D", "Lj7ImpCFArg | nAliqIVA", nAliqIVA)
	LjGrvLog( "LOJA701D", "Lj7ImpCFArg | Len(aImpDifIVA)", Len(aImpDifIVA) )
	
	cValDescIt 	:= Str(nValDescIt,9,2)                                               
	cProduto  	:= IIF(!lImpTick,Padr(cProduto,20),Alltrim(cProduto))
	cDescProd 	:= AllTrim(cDescrip)
	cRetorno  	:= " "  

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Venda Assistida Sem a concomitancia ativada (MV_LJVACC=F) 				     ³
	//³ Nao imprime pq se estiver com venda concomitante jah foi impresso o item     |
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ	
    If !lVAssConc            

		If LJAnalisaLeg(39)[1]
	    	dbSelectArea("SB1")
	    	SB1->(dbSetOrder(1))
	    	If SB1->(dbSeek(xFilial("SB1") + cProduto))
	    		If !Empty(SB1->B1_CODBAR)
					cProduto := SB1->B1_CODBAR
				EndIf
			EndIf
	    EndIf
	    
	    If lLj7013
	    	cSitTrib := Str(nAliqIVA) + "|" + Str(nAliq)
	    	cVlrItem := Str((nVlrUnit * nQuant),12,4)
			aRetLj7013 := ExecBlock("LJ7013",.F.,.F.,{cProduto, cDescProd, cQuant, cUnit, cValDescIt, cSitTrib, cVlrItem })
			If ValType( aRetLj7013 ) == "A" .AND. Len( aRetLj7013 ) >= 7
				cProduto 		:= aRetLj7013[1]
				cDescProd		:= aRetLj7013[2]
				cQuant 			:= aRetLj7013[3]
				cUnit			:= aRetLj7013[4]
				cValDescIt		:= aRetLj7013[5]
				nPosHas			:= AT("|",aRetLj7013[6])
				nAliqIVA	    := Val(Substr(aRetLj7013[6],1,nPosHas-1))
				nAliq			:= Val(Substr(aRetLj7013[6],nPosHas+1))
				cVlrItem		:= aRetLj7013[7]
			EndIf
		EndIf
	
   	    If cA1Tipo == "C"
	    	cTipoImp := "1"
	    ElseIf SF4->(FieldPos("F4_TIPOTES") > 0 )
	    	cTipoImp := SF4->F4_TIPOTES
	    Else
	    	cTipoImp := "2" 
	    EndIf
	    cTipoImp := "2" //Definido como "2" para indicar para a impressora que o valor do produto enviado nao contem IVA, assim a impressoa deve fazer o calculo
	    
	    If lLj7093
	    	cRetLj7093 := ExecBlock("LJ7093",.F.,.F.)
	    	If !ValType(cRetLj7093) == "C"
				cRetLj7093 := ""
	    	EndIf
	    EndIf
	    
	    If !Empty(cRetLj7093)
		    nRet := IFImpTxtFis( nHdlECF , cRetLj7093) 
		EndIf
	    
	    If nRet == 0	

			LjGrvLog( "LOJA701D", "Lj7ImpCFArg | nAliqIVA", nAliqIVA)

			nRet	:=	IFRegItem( nHdlECF			, AllTrim(cProduto)  , AllTrim(cDescProd)	      , AllTrim(cQuant)	, ;
									AllTrim(cUnit)	, AllTrim(cValDescIt), AllTrim(Str(nAliqIVA,5,2)) + "|" +            ;
						   			AllTrim(Str(nTotImpInt,14,2)) + " |" + cIncluiIVA, cVlrItem, cUnidMed,	cTipoImp)
		EndIf
	EndIf

	If nRet <> 0
		If !lAutoExD
			MsgAlert( STR0065 )
		Else
			Conout( STR0065 )
		Endif
		LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', "LOJA701D - IFCancCup - IFRegItem ********************")
		nRet := IFCancCup( nHdlECF )
		LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', "LOJA701D - IFCancCup - IFRegItem - Retorno: "+Str(nRet))
		Return ({.F.,aRetPDV,''})
	EndIf

	SL2->(DbSkip())
End
RestArea(aAreaSL2)

If SL1->L1_DESCONT > 0 .OR. SE4->E4_DESCFIN <> 0 .OR. Lj7T_DescV(2) > 0
	If	cSerie == "B" .AND. ( LjGetStation("LG_IMPFISC") == AllTrim( "EPSON TM-U220AF" ) .OR.;
		LjGetStation("LG_IMPFISC") == AllTrim( "EPSON TM-300AF+" ) .OR. LjGetStation("LG_IMPFISC") == AllTrim( "EPSON TM-2000AF+" ) )

		// Posiciona no primeiro item.
		aAreaSL2 := GetArea()
		SL2->( DbSetOrder( 1 ) )
		SL2->( DbSeek( xFilial( "SL2" ) + SL1->L1_NUM ) )

		nX := 1
		While !SL2->(Eof()) .AND. (SL2->L2_FILIAL + SL2->L2_NUM == xFilial("SL2")+SL1->L1_NUM)
			If !aCols[nX][Len(aCols[nX])]
				For nY := 1 To 9
					If SL2->(FieldPos("L2_VALIMP" + cValToChar(nY))) > 0 
						If &("SL2->L2_VALIMP" + cValToChar(nY)) > 0
							nDesconto += Round( ((aCols[nX][nPosVlrItem]+nTotImp)/(1 + (&("SL2->L2_ALQIMP" + cValToChar(nY))/100))) * (1 + (&("SL2->L2_ALQIMP" + cValToChar(nY))/100)), 2)
						EndIf
					EndIf
				Next nY
				SL2->(DbSkip())
			EndIf
			nX++
		End
		nX:= 1
	   	While nX < 6 .AND. nQtdAliq < 2
			If &("SL1->L1_VALIMP" + cValToChar(nX)) > 0
			    nQtdAliq++
			    nAliquota := Round((&("SL1->L1_VALIMP" + cValToChar(nX)) * 100) / &("SL1->L1_BASIMP" + cValToChar(nX)), 2)
			EndIf
			nX++
		End
		If nQtdAliq > 1
			nDesconto := Round( nDesconto * ( SL1->L1_DESCNF / 100 ), 2)
		Else
			nDesconto := Round( Lj7T_DescV(2) * ( 1 + (nAliquota / 100) ), 2)
		EndIf
		cDescTotal := " |"+Strzero( nDesconto, 12, 2)+"|0|"
		RestArea(aAreaSL2)
	Else
		cDescTotal := " |"+Strzero(SL1->L1_DESCONT,12,2)+"|0|"
	EndIf

    IFDescTot(nHdlECF,cDescTotal, Nil,cTipoCli)

   	cDescTotal := " |"+Strzero(SL1->L1_DESCONT,12,2)+"|0|"

	cDescTotal := Replace( cDescTotal, "|", "")
    cDescTotal := SubStr( cDescTotal, 1, Len( cDescTotal ) - 1 )
EndIf

If (Len(aAcrescimo) > 0 .AND. (aAcrescimo[1] > 0 .OR. aAcrescimo[2] > 0)) .OR. (Len(aTaxJuros) > 0 .AND. aTaxJuros[1] > 0)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Acrescimo para fatura A deve ser calculado sobre o valor liquido.³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nVlrAcrs	:= Lj7T_Total(2) - Lj7T_Subtotal(2)

	cTotAcrs   := " |" + StrZero( nVlrAcrs,12,2) + "|0|"
	
	IFAcresTot(nHdlECF,cTotAcrs)
	cTotAcrs   := " |" + StrZero( nVlrAcrs,12,2) + "|0|"
	cTotAcrs := Replace( cTotAcrs, "|", "")
	cTotAcrs := SubStr( cTotAcrs, 1, Len( cTotAcrs ) - 1 )
EndIf

If !Lj7ImprTot( Val(cTotAcrs), Val(cDescTotal), IIf(aAcrescimo[1] > 0, aAcrescimo[2], 0 ), aTaxJuros )
	LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', "LOJA701D - IFCancCup - Lj7ImprTot ********************")
	nRet := IFCancCup( nHdlECF )
	LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', "LOJA701D - IFCancCup - Lj7ImprTot - Retorno: "+Str(nRet))
	If nRet <> 0
		lRet := Lj7CFImpreso(.T.)
		aadd(aLog, "LOJA701D - Lj7ImpCFArg - Lj7ImprTot - INÍCIO")
		aadd(aLog, "Usuário: "+cUserName)
		aadd(aLog, STR0064)
		aadd(aLog, IIf(lRet, "Sim", "Não"))
		aadd(aLog, "LOJA701 - Lj7AtuPgto - Lj7ImprTot - FIM")
		LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', aLog)

		If lRet
			nRet := 0
		Else
			Return ({.F.,aRetPDV,''})
		EndIf
	Else
		Return ({.F.,aRetPDV,''})
	EndIf
	
	Return ({.F.,aRetPDV,''})
EndIf
nLineRod	:=	11

cMensagem := ""

If AllTrim(SM0->M0_ESTCOB) == "BA"
	cMensagem := STR0061 + '.' + cMensagem   //"Orientação ao Consumidor Província de Buenos Aires 0800 222 9042"
EndIf

If cMensagem <> "" 
	cMensagem += "_"
EndIf	

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se ha mensagem promocional e fecha o cupom.³
//³Caracter para quebra de linha '_'                   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Substr(cMvLjFisMs,1,1)=="&"
	cMvLjFisMs := &(Substr(cMvLjFisMs,2,Len(cMvLjFisMs)))
EndIf
   
cMensagem += AllTrim(cMvLjFisMs) 

If cMensagem <> "" 
	cMensagem += "_"
EndIf	

cMensagem += AllTrim(LjGetStation("LG_MSGCUP"))
LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', "LOJA701D - IFFechaCup ********************")


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Fecha o cupom fiscal ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lTentarNovamente := .T.
While lTentarNovamente 
	nRet := IFFechaCup(nHdlECF, cMensagem)
	lTentarNovamente := nRet <> 0 .AND. MsgYesNo(STR0072) //"Problema com o fechamento do cupom fiscal. Tentar novamente?"
End  

LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', "LOJA701D - IFFechaCup - Retorno: "+Str(nRet))
If nRet <> 0
	lRet := Lj7CFImpreso(.F.)
	aadd(aLog, "LOJA701D - Lj7ImpCFArg - IFFechaCup - INÍCIO")
	aadd(aLog, "Usuário: "+cUserName)
	aadd(aLog, STR0064)
	aadd(aLog, IIf(lRet, "Sim", "Não"))
	aadd(aLog, "LOJA701 - Lj7AtuPgto - IFFechaCup - FIM")
	LjWriteLog(cLogPath + M->LQ_NUM + '.TXT', aLog)

	If lRet
		nRet := 0
	Else
		Return( { .F. , {cNumCup,cNumPdv},'' } )
	EndIf
EndIf                        

aRet := { .T. , {cNumCup,cNumPdv},'' }

If ( nImpSegVia > 0 ) .AND. lFiscal .AND. lImpTick
	For nY := 1 to nImpSegVia
		If xOpt == 2        
			nRet :=	IFReimprime(nHdlECF)
		EndIf

		While nRet <> 0 .AND. xOpt == 2
			L010AskImp( @xOpt , nRet, .F.)
			If xOpt == 2
				nRet :=	IFReimprime(nHdlECF)		//Efetua a Reimpressao do cupom em impressoras Hasar
			EndIf
		End
	Next nY
EndIf

Return aRet

/*
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funci¢n   ³ GrabLogHsr³ Autor ³ Vendas Clientes       ³ Data ³          ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descrip.  ³ Grabacion de Log                                            ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Uso       ³ HASAR SMH/PL-8F y SMHP-PR4F                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametro ³                                                             ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function GrabLogHsr( cText )

Local cFile	:= '\LOGHASAR\'

xNumCaixa()

cFile += SA6->A6_COD + SubStr(  Dtos( dDataBase ), 5 ) + '.LOG'

If !File(cFile)
	nHnd	:= FCreate( cFile )
Else
	nHnd	:= FOpen( cFile, 2 )
EndIf

FSeek( nHnd, 0, 2 )
FWrite( nHnd, Time() + '  ' + cText + Chr(13) + Chr(10) )

FClose( nHnd )

Return

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºFuncao    ³Lj7ImprTotºAutor  ³Vendas Clientes     º Data ³  26/01/04   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Hace la impresion del total tender en la factura           º±±
±±º          ³ (localizações Argentina).                                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametro ³ExpN1 :=Valor de acrescimo da venda                         º±±  
±±º          ³ExpN2 :=Valor de desconto  da venda                   	  º±±  
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja - Venda Assistida                                 º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7ImprTot( nAcresTotal, nDescTotal, nAcresPerc, aTaxJuros )

Local nImp			:= 0
Local nItem			:= 0
Local nTotPag		:= 0
Local _nIVA			:= 0
Local _nTotal		:= 0
Local nIBP			:= 0
Local nIB2			:= 0
Local nIB4			:= 0
Local nIB5			:= 0
Local nIB6			:= 0
Local nIB7			:= 0
Local nIB8			:= 0
Local nIBA			:= 0
Local nIBB			:= 0
Local nIBC			:= 0
Local nIBD			:= 0
Local nIBE			:= 0
Local nIBF			:= 0
Local nIBG			:= 0
Local nIBH			:= 0
Local nIBI			:= 0
Local nIBJ			:= 0
Local nIBK			:= 0
Local nIBL			:= 0
Local nIBM			:= 0
Local nIBN			:= 0
Local nIBO			:= 0
Local nIVP			:= 0
Local nTotPecep		:= 0
Local nRet			:= 1
Local cAliqIVA		:= ""
Local cTexto		:= ""
Local cValor		:= ""
Local cRetorno		:= ""
Local cPercepcion	:= ""
Local aRet			:= {}
Local lTentarNovamente := .T.	// Tentar enviar o comando ao ECF novamente?
Local lAbortaCF 	:= .F.

Default nAcresPerc 	:= 0 
Default aTaxJuros		:= {}

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Perceptions - Impresion de Percepciones  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nIB2 := 0
nIBP := 0
For nItem := 1 To Len(aImpsSL2)
	For nImp := 1 To Len(aImpsSL2[nItem][3])
		If aImpsSL2[nItem][3][nImp][4] > 0
			If Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IB2"
				nIB2	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBP"
				nIBP	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IB4"
				nIB4	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IVP"
				nIVP	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IB5"
				nIB5	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IB6"
				nIB6	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IB7"
				nIB7	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IB8"
				nIB8	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBA"
				nIBA	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBB"
				nIBB	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBC"
				nIBC	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBD"
				nIBD	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBE"
				nIBE	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBF"
				nIBF	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBG"
				nIBG	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBH"
				nIBH	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBI"
				nIBI	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBJ"
				nIBJ	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBK"
				nIBK	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBL"
				nIBL	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBM"
				nIBM	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBN"
				nIBN	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			ElseIf Upper(AllTrim(aImpsSL2[nItem][3][nImp][1])) $ "IBO"
				nIBO	+=	aImpsSL2[nItem][3][nImp][4] * (1+(nAcresPerc/100))
			EndIf
		EndIf
	Next nImp
Next nItem

nTotPecep := (	nIB2 + nIBP + nIB4 + nIB5 +;
				nIB6 + nIB7 + nIB8 + nIBA +;
				nIBB + nIBC + nIBD + nIBE +;
				nIBF + nIBG + nIBH + nIBI +;
				nIBJ + nIBK + nIBL + nIBM +;
				nIBN + nIBO + nIVP	)

If nIB2 > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Bs.As."
	cValor    := AllTrim(Str(nIB2,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIB4 > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Tucuman"
	cValor    := AllTrim(Str(nIB4,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIVP > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. IVA"
	cValor    := AllTrim(Str(nIVP,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBP > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Cap.Fed"
	cValor    := AllTrim(Str(nIBP,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIB5 > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Catamarca"
	cValor    := AllTrim(Str(nIB5,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIB6 > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Chabut"
	cValor    := AllTrim(Str(nIB6,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIB7 > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Chaco"
	cValor    := AllTrim(Str(nIB7,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIB8 > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Cordoba"
	cValor    := AllTrim(Str(nIB8,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBA > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Entre Rios"
	cValor    := AllTrim(Str(nIBA,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBB > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Formosa"
	cValor    := AllTrim(Str(nIBB,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBC > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Jujuy"
	cValor    := AllTrim(Str(nIBC,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBD > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. La Pampa"
	cValor    := AllTrim(Str(nIBD,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBE > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. La Rioja"
	cValor    := AllTrim(Str(nIBE,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBF > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Mendoza"
	cValor    := AllTrim(Str(nIBF,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBG > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Misiones"
	cValor    := AllTrim(Str(nIBG,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBH > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Neuquen"
	cValor    := AllTrim(Str(nIBH,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBI > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Salta"
	cValor    := AllTrim(Str(nIBI,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBJ > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Santa Cruz"
	cValor    := AllTrim(Str(nIBJ,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBK > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Santa Fe"
	cValor    := AllTrim(Str(nIBK,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBL > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Rio Negro"
	cValor    := AllTrim(Str(nIBL,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBM > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Santiago del Estero"
	cValor    := AllTrim(Str(nIBM,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBN > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. San Juan"
	cValor    := AllTrim(Str(nIBN,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

If nIBO > 0
	cAliqIVA  := "**.**"
	cTexto    := "Perc. Tierra del Fuego"
	cValor    := AllTrim(Str(nIBO,14,2))
	cPercepcion += cAliqIVA+"|"+cTexto+"|"+cValor+"|"
EndIf

xNumCaixa()

cRetorno  := " |c|0" + Space(50) 
nRet      := IFSubTotal(nHdlECF,@cRetorno)
If nRet == 1
	Return(.F.)
EndIf

aRet := LjStr2Array(cRetorno)
If Len( aRet ) < 3
	If Type("lAutoExec") <> "L" .OR. !lAutoExec		
		MsgAlert(STR0038)    //"Erro no Sub-Total do documento. Erro da Impressora Fiscal"
	Else
		Conout(STR0038)    //"Erro no Sub-Total do documento. Erro da Impressora Fiscal"
	EndIf
	GrabLogHsr( STR0039 + SL1->L1_NUM )   //"Erro no Sub-Total, nao retorna os dados do documento"

	nRet  := IFCancCup(nHdlECF)
	If nRet == 1
		Return( .F. )
	EndIf
	
	Return( .F. )
ElseIf Len( aRet ) > 4
	_nIVA	:= If(aRet[5] == NIL, 0, Val( aRet[5] )) //Total de IVA
	_nTotal	:= If(aRet[4] == NIL, 0, Val( aRet[4] )) //Total da venda
	nTotPag	 :=	_nTotal + nTotPecep						//Soma as Percepciones
EndIf

//Ponto de Entrada "LJ701DAC" especifico criado para o cliente Resta Sanitarios para fazer o tratamento do valor total retornado pela impressora 
// e o valor total do Protheus, permitindo assim abortar a impressão da Factura antes que a venda seja finalizada.
If ExistBlock("LJ701DAC")
	lAbortaCF	:= ExecBlock("LJ701DAC",.F.,.F.,{nTotPag,Lj7T_Total(2)})
	If lAbortaCF
		Return(.F.)
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ TotalTender - Total pagado en letras   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nNCCUsada > 0 
    nTotPag := IIF( (nTotPag + 0.01 == Lj7T_Total(2)) .OR. (nTotPag - 0.01 == Lj7T_Total(2)), Lj7T_Total(2), nTotPag)                                             
	cRetorno := Lj7DefForm(	nTotPag	, NIL		, NIL		, NIL  		,; 
							NIL		, NIL		, NIL		, NIL  		,;
							aTaxJuros )  
Else
	cRetorno := Lj7DefForm(	nTotPag	, nAcresTotal, nDescTotal, NIL		,;
							NIL		, NIL		 , NIL		 , NIL		,;
							aTaxJuros )
EndIf

If Len(cPercepcion)>0
	cPercepcion := SubStr(cPercepcion, 1, Len(cPercepcion)-1)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Emite os pagamentos ao ECF ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
lTentarNovamente := .T.
While lTentarNovamente 
	nRet := IFPagto( nHdlECF, cRetorno, cValToChar( Lj7T_Total(2)), Lj7T_Total(2), NIL, cPercepcion, If(cPaisLoc <> "BRA", aImpsSL1, NIL) )
	lTentarNovamente := nRet <> 0 .AND. MsgYesNo(STR0071) // "Problema com a impressão do pagamento. Tentar novamente?"
End  

If nRet == 1
	Return(.F.)
EndIf

Return .T.                                       

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Fun‡„o    ³ LJ7ImpItCC   ³ Autor ³ Vendas Clientes      ³ Data ³ 27/07/2005 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³ Imprime o item quando for venda Assistida concomitante          ³±±
±±³          ³ MV_LJVACC =  T												   ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³ SigaLoja                                                        ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function LJ7ImpItCC(	nItem, aTmpCols, aTmpHeader, aIcms ,;
 						lEndVendCC , cVendido,nImpItCC )

Local lRet 			 := .T.										// Retorno da funcao 
Local nRet           := 0          								// Retorno do status da impressao
Local cNumCupom 	 := Space(TamSX3("LR_NUM")[1])      		// Numero do proximo cupom
Local cNumPdv 		 := Space(TamSX3("LR_PDV")[1])				// Numero do PDV que ira imprimir o cupom 
Local cRetorno		 := Space(10)								// Variavel de retorno
Local cCodProd       := ""										// Codigo do Produto na linha de digitacao atual
Local nPosDescr      := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESCRI"})][2]		// Posicao da Descricao do produto
Local cDescriProd    := ""										// Descricao do produto
Local cQuant         := ""                                      // Quantidade do Produto na linha de digitação
Local cVrUnit        := ""                                      // Valor unitario                                                		
Local cDesconto      := "" 										// Desconto do item
Local nPosValIpi	 := aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))=="LR_VALIPI" })
Local cVlrItem	     := ""										// Valor do item
Local cSitTrib       := ""										// Situacao tributaria
Local cUnidMed       := SB1->B1_UM								// Unidade de medida
Local cUnit          := ""										// Unidade
Local nVlrIcmsRet	 := 0										// Icms retido
Local nVlrTotIcmsRet := 0										// Valor do ICMS retido
Local lImpOk		 := .F.										// Impresso OK
Local cValDescIt     := ""										// Desconto do Item
Local nAliqIVA       := 0										// Aliquota do Imposto IVA
Local nAliq          := 0										// Aliquota
Local cIncluiIVA     := ""										// Inclui IVA
Local nAliquota		 := 0										// Aliquota
Local nAliqRed       := 0										// Aliquota de Reducao
Local cTpSolCf       := SuperGetMv("MV_TPSOLCF")                //Parametro para validacao do tipo de cliente para o calculo do solidario
Local lLj7013		 := ExistBlock("LJ7013",Nil,.T.)			// Ponto de entrada
Local lChaFinalVD	 := .F.									    // Verifica se estah sendo chamada da finalizacao da venda
Local nPosTes		 := aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))=="LR_TES" }) // Tes
Local nPosProd		 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_PRODUTO"})][2]	// Posicao da codigo do produto
Local nPosDesc		 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_DESC"})][2]		// Posicao do percentual de desconto
Local nPosValDesc	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VALDESC"})][2]	// Posicao do valor de desconto
Local nPosQuant		 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_QUANT"})][2]		// Posicao da Quantidade
Local nPosVlItem	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VLRITEM"})][2]	// Posicao do Valor do item
Local nPosVlUnit	 := aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1])) == "LR_VRUNIT"})][2]		// Posicao do Valor unitario do item
Local nPosStTrib	 := Ascan(aPosCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_SITTRIB"})				// Posicao da situacao tributaria
Local nPosPrctab	 := Ascan(aposCpoDet,{|x| AllTrim(Upper(x[1])) == "LR_PRCTAB" })
Local nVlrIPI        := 0
Local lVAssConc	     := LjVassConc()						//Indica se o cliente utiliza a Vda Assistida Concomitante
Local aTamL2_VALDESC := TamSX3("L2_VALDESC")				// Tamanho do campo L2_VALDESC
Local aTamL2_VRUNIT  := TamSX3("L2_VRUNIT")					// Tamanho do campo L2_VRUNIT
Local aTamL2_VLRITEM := TamSX3("L2_VLRITEM")				// Tamanho do campo L2_VLRITEM
Local lFunImp		 := .F.									// Se a funcao da impressora eh 01 no LojxEcf
Local lVerHora		 := .T.									// Se a hora eh para verificar a hora, dependendo do retorno do LojxEcf
Local lAutoExD		 := IsBlind()							// Verifica se a rotina sera executada via execauto ou nao
Local lCancECF		 := .F.									// Se irá realizar o cancelamento do item no ECF

Local lFTVD7013	 	 := ExistBlock("FTVD7013")				// Ponto de entrada
Local lMVLJPRDSV   	 := SuperGetMv("MV_LJPRDSV",.F.,.F.)	// Verifica se esta ativa a implementacao de venda com itens de "produto" e itens de "servico" em Notas Separadas
Local cMvLjTGar		 := SuperGetMV("MV_LJTPGAR",,"GE")     	// chama a user function
Local lMVLJIMPGF	 := SuperGetMv("MV_LJIMPGF",,.F.)
Local lTemItProd 	 := If(!lMVLJPRDSV,.F.,.T.)
Local lImpItem		 := .T.									// Verifica se item é do tipo retira para realizar a impressão
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Default lEndVendCC	 	:= .F.								// Finaliza Venda Concomitante
DEFAULT cVendido	 	:= ""			                    // Se possuir "N", sinaliza que o item deverá ser cancelado logo após a impressão
DEFAULT nImpItCC		:= 0								// utilizado para semaforo, pois deve ser aberto o cupom fiscal uma unica vez			

// Faz a mesma checagem da venda nao concomitante
lMVLJPRDSV := lMVLJPRDSV .And. Empty(SL1->L1_ORCRES) .And. Empty(SL1->L1_DOCPED)
lTemItProd := If(lMVLJPRDSV,.T.,.F.)

If lMVLJPRDSV .And. ExistFunc("LjCheckRPS")    
	LjCheckRPS(SL1->L1_NUM, @lTemItProd, Nil)
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Faz um tratamento para saber se esta funcao estah sendo cha- ³
//³ mada da validacao do produto na digitacao ou na finalizacao  ³
//³ da venda. Caso afirmativo forca a criacao da aCols e aHader  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If Valtype(aTmpCols) == "A"
	lChaFinalVD := .T.
	aCols := aTmpCols
EndIf	

If Valtype(aTmpHeader) == "A"
	aHeader := aClone( aTmpHeader )
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se for chamada da finalizacao, forca a inicializacao da variavel n   ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lChaFinalVD
	n := nItem
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inicializa as variaveis                                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
cCodProd      := aCols[nItem][nPosProd]
cDescriProd   := aCols[nItem][nPosDescr]                                                 
cDesconto     := Str(aCols[nItem][nPosValDesc],aTamL2_VALDESC[1],nDecimais) 

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se o produto nao tiver preco nao envia para o ECF            ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. ( aCols[nItem][nPosVlItem] <= 0 .OR. aCols[nItem][nPosVlUnit] <= 0 )
	If Type("lAutoExec") <> "L" .OR. !lAutoExec		
		MsgAlert( STR0046 + AllTrim(aCols[nItem][nPosDescr]) + STR0047 ) // "O produto " - " está sem preço de venda e não será registrado!"
	Else
		Conout( STR0046 + AllTrim(aCols[nItem][nPosDescr]) + STR0047 ) // "O produto " - " está sem preço de venda e não será registrado!"
	EndIf	
	lRet := .F.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica a data da impressora, nao permite a impressao se a  ³
//³ data do ECF for diferente da data do sistema                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. LjEcfIFData( @lFunImp, @lVerHora )
	If !lFunImp 	    
		If !VerifHora()
		    lRet := .F.
		EndIf
	Else
		If !lVerHora
			lRet := .F.
		EndIf		
	EndIf
EndIf
If cGetCliDir == NIL
   cGetCliDir := GetClientDir()
EndIf 
If !File( cGetCliDir+"SIGALOJA.INI" )
	WritePProString("Condicao de Pagamento", "Retencoes", "RETENCOES", cGetCliDir+"SIGALOJA.INI")
EndIf

If lRet .AND. nImpItCC == 1 
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica se ha um cupom em aberto. Caso afirmativo, faz o    ³
	//³ cancelamento antes da abertura de outro                      ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nRet := IFStatus( nHdlECF, '5', @cRetorno )
	If nRet == 7
		nRet := IFCancCup( nHdlECF )
		If Lj7VerCmd( nRet )
			Inkey(8)   // dá um tempo para a impressora fazer a impressao do cancelamento
		Else
			lRet := .F.
		EndIf
	EndIf
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Abre o cupom fiscal                                          ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If LjAnalisaLeg(42)[1]
		If !LjCxAberto(.T.,xNumCaixa())
			nRet := 1
		Else
			nRet := IFAbreCup(nHdlECF ,Nil ,Nil ,Nil ,@lImpCpfNpj )
		EndIf
	
	Else
		nRet := IFAbreCup(nHdlECF,Nil ,Nil, Nil ,@lImpCpfNpj)
	EndIf
	If !Lj7VerCmd( nRet )
		lRet := .F.
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Pega o numero do cupom fiscal                                ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nRet := IFPegCupom( nHdlECF, @cNumCupom )
	If !Lj7VerCmd( nRet )
		lRet := .F.
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Pega o numero do PDV                                         ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nRet := IFPegPDV( nHdlECF, @cNumPdv )
	If !Lj7VerCmd( nRet )
		lRet := .F.
	EndIf
EndIf

//verifica status antes de prosseguir, para emitir msg de Alerta
If lRet .AND. LjHomolPaf() .And. LjVassConc()
	nRet := IFStatus( nHdlECF, '3', @cRetorno )
	If nRet <> 0
		If nRet == 3
			MsgStop("Fim de papel no ECF. Verifique!")
			lRet := .F.
		ElseIf nRet == 2
			MsgStop("Pouco papel no ECF. Verifique!")
		EndIf
	EndIf

	//Deve validar o arquivo criptografado
	If lRet .AND. !LjVldSerie()
		lRet := .F.
	EndIf
EndIf

//Apresenta mensagem informando erro no ECF
If !lRet
	If !lAutoExD		
		MsgStop( STR0049 + AllTrim(Upper(cDescriProd))+ STR0050 )   //"Não foi possível registrar o item "...+" devido a problemas no ECF. Este produto será excluído!!"
	Else
		Conout( STR0049 + AllTrim(Upper(cDescriProd))+ STR0050 )   //"Não foi possível registrar o item "...+" devido a problemas no ECF. Este produto será excluído!!"
	Endif
EndIf      

If lRet 
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Posiciona o SB1   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea( "SB1" )
	SB1->(DbSetOrder(1))
	SB1->(DbSeek(xFilial("SB1")+ cCodProd ))

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Posiciona o SB0   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea( "SB0" )
	SB0->(DbSetOrder(1))
	SB0->(DbSeek(xFilial("SB0")+SB1->B1_COD))

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Posiciona o SF4   ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	DbSelectArea( "SF4" )
	SF4->(DbSetOrder(1))
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Se for chamada da finalizacao, pesquisa como TES gravado             ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

	If lChaFinalVD
	   SF4->(DbSeek(xFilial("SF4")+SL2->L2_TES ))
	Else
	   SF4->( DbSeek( xFilial("SF4") + aColsDet[n][nPosTes] ) )
	EndIf   
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica a situacao tributaria do item                       ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7Strib( @cSitTrib, @nAliquota, @nAliqRed, cTpSolCf, nItem )

	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Verifica na venda concomitante se a aliquota esta permitida  ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lVAssConc
	   lRet := Lj7ChkIcm( nAliquota, aIcms )
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Trata as variaveis para o registro do item                   ³	
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If nPosValIPI > 0
	   nVlrIPI  := aColsDet[n][nPosValIPI]
	EndIf
	
	//O padrao era calcular o cVrUnit com base no aCols, apos alteracao do dia 27/05/14 passou a calcular do aColsDet considerando o PRCTAB, para manter compatibilidade com outros modulos que tambem geram SL2 sem utilizar o LOJA701(), foi validado se possui PRCTAB, caso não, calcula com base no aCols.
	If aColsDet[nItem][nPosPrctab] > 0
		cVrUnit	 := Str(aColsDet[nItem][nPosPrctab] + (nVlrIPI/aCols[nItem][nPosQuant]) + (nVlrIcmsRet/aCols[nItem][nPosQuant]),aTamL2_VRUNIT[1],nDecimais)
	Else
	    cVrUnit	 := Str(((( ( aCols[nItem][nPosVlUnit] + (( aCols[nItem][nPosValDesc] + nVlrIPI ) / aCols[nItem][nPosQuant] )) * aCols[nItem][nPosQuant]) + nVlrIcmsRet ) / aCols[nItem][nPosQuant]),aTamL2_VRUNIT[1],nDecimais)	
	EndIf

	cQuant 	 := StrZero(aCols[nItem][nPosQuant],8,3)
	cVlrItem := Str(aCols[nItem][nPosVlItem] + aCols[nItem][nPosValDesc] + nVlrIPI + nVlrIcmsRet,aTamL2_VLRITEM[1],nDecimais)
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Ponto de entrada para tratamento das informacoes a serem     ³
	//³ enviadas para o ECF. Utiliza o mesmo ponto de entrada usado  ³
	//³ nas vendas nao concomitantes                                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	If lLj7013 .AND. !lFtvdVer12

		aRetLj7013 := ExecBlock("LJ7013",.F.,.F.,{cCodProd, cDescriProd, cQuant, cVrUnit, cDesconto, cSitTrib, cVlrItem })
		If ValType( aRetLj7013 ) == "A" .AND. Len( aRetLj7013 ) >= 7
			cCodProd 	:= aRetLj7013[1]
			cDescriProd	:= aRetLj7013[2]
			cQuant 		:= aRetLj7013[3]
			cVrUnit		:= aRetLj7013[4]
			cDesconto	:= aRetLj7013[5]
			cSitTrib	:= aRetLj7013[6]
			cVlrItem	:= aRetLj7013[7]
		EndIf
	EndIf 
	
	If lFTVD7013 .AND. lFtvdVer12
	
		aRetFTVD7013 := ExecBlock("FTVD7013",.F.,.F.,{cCodProd, cDescriProd, cQuant, cVrUnit, cDesconto, cSitTrib, cVlrItem })
		If ValType( aRetFTVD7013 ) == "A" .AND. Len( aRetFTVD7013 ) >= 7
			cCodProd 		:= aRetFTVD7013[1]
			cDescriProd		:= aRetFTVD7013[2]
			cQuant 			:= aRetFTVD7013[3]
			cVrUnit			:= aRetFTVD7013[4]
			cDesconto		:= aRetFTVD7013[5]
			cSitTrib		:= aRetFTVD7013[6]
			cVlrItem		:= aRetFTVD7013[7]
			
		EndIf
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Guarda a situacao tributaria do item    	                 ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ		
	If nPosStTrib > 0
		aColsDet[nItem][nPosStTrib] := cSitTrib
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Imprime os itens validando                                   ³
//| a impressao do codigo de barras para venda nao concomitante  |
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

If lRet
	cMvCodBar := SuperGetMv("MV_CODBAR",,"N")
	cCodProd := Lj701DSLK(cCodProd,SB1->B1_CODBAR,cMvCodBar)

    If LJAnalisaLeg(39)[1]
    	dbSelectArea("SB1")
    	SB1->(dbSetOrder(1))

    	If SB1->(dbSeek(xFilial("SB1") + cCodProd))
    		If !Empty(SB1->B1_CODBAR)
    	   		cCodProd := SB1->B1_CODBAR
    	 	EndIf
    	EndIf
    
    EndIf

	/* Verifica se item é do tipo retira para realizar a impressão  */
	If lMVLJPDVPA 
		lImpItem := Empty(SL2->L2_ENTREGA) .OR. (SL2->L2_ENTREGA == "2")
	EndIf
		 
	If (lMVLJIMPGF .AND. SB1->B1_TIPO == cMvLjTGar)
		lImpItem := .F.	
	EndIf
	
	If lImpItem
		cDescriProd := LjDscCESCF(cDescriProd,nItem)
	
		nRet := IFRegItem( nHdlECF, cCodProd , cDescriProd, cQuant,;
						   cVrUnit, cDesconto, cSitTrib   , cVlrItem,;
						   cUnidMed )
	Endif
							   
	If !Lj7VerCmd( nRet )
		
		//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
		//³ Se falhar a impressao do item, faz a delecao na aCols para nao haver ³
		//³ divergencias entre o cupom fiscal e a tela de vendas                 ³
		//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		If Type("lAutoExec") <> "L" .OR. !lAutoExec	
			MsgStop( STR0049 + AllTrim(Upper(cDescriProd))+ STR0050 )   //"Não foi possível registrar o item "...+" devido a problemas no ECF. Este produto será excluído!!"
		Else
			Conout( STR0049 + AllTrim(Upper(cDescriProd))+ STR0050 )   //"Não foi possível registrar o item "...+" devido a problemas no ECF. Este produto será excluído!!"
		EndIf	
		lRet := .F.
	EndIf
EndIf

//PAFECF: Sinaliza que item deve ser cancelado no aCols e no ECF -> Itens quando origem Importacao de Orcamento(PAF-ECF) e item cancelado enquanto era Orcamento
If lMVLJPDVPA .AND. cVendido == "N"
	lCancECF := .T.
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Se houve algum erro com o registro do item no ECF ou se item         ³
//³ cancelado(lCancECF) na geracao do orcamento(PAF-ECF DAV/Pre Venda),  ³
//³ faz a delecao na aCols e no aColsDet                                 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lRet .OR. lCancECF
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Chama a funcao de validacao da Delecao do padrao da Venda Assistida  ³
	//³ mas nao serah necessario enviar o cancelamento para o ECF            ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	Lj7ValDel( lCancECF, .F., .F.,lEndVendCC)	
	aCols[n][Len(aCols[n])]		:= .T.
	If Len(aColsDet) >= n
	   aColsDet[n][Len(aColsDet[n])] := .T.
	EndIf
ElseIf LjVassConc() .And. ExistFunc("LjLogItCC")
	LjLogItCC()
EndIf

Return lRet 

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±³Fun‡„o    ³ Lj7Strib     ³ Autor ³ Vendas Clientes      ³ Data ³ 27/07/2005 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡„o ³ Verifica a situacao tributaria do item                          ³±±
±±³          ³ 					   						   				       ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³ Uso      ³ SigaLoja                                                        ³±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7Strib( cSitTrib, nAliquota, nAliqRed, cTpSolCf, nItem ) 
Local aLjExcecao	:= {}
Local lEmitNfce		:= LjEmitNFCe()									//Sinaliza se utiliza NFC-e
Local cAliasSB		:= "SB1"																			//Funcao utilizada apenas no SigaLoja
Local nPICMRET		:= IIF(lEmitNfce .Or. lIsPafNfce,RetFldProd(SB1->B1_COD,"B1_PICMRET",cAliasSB),SB1->B1_PICMRET) 	//Tratamento SBZ
Local nPICMENT		:= IIF(lEmitNfce .Or. lIsPafNfce,RetFldProd(SB1->B1_COD,"B1_PICMENT",cAliasSB),SB1->B1_PICMENT) 	//Tratamento SBZ
Local nALIQISS		:= IIF(lEmitNfce .Or. lIsPafNfce,RetFldProd(SB1->B1_COD,"B1_ALIQISS",cAliasSB),SB1->B1_ALIQISS) 	//Tratamento SBZ
/*As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - 
alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo 
para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo*/
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local lF4MKPSOL 	:= SF4->(ColumnPos("F4_MKPSOL")) > 0
Local lExcecaoFcl	:= .F.
Local lExecPE7017	:= .F.

DEFAULT cSitTrib	:= ""
DEFAULT nAliquota   := 0
DEFAULT nAliqRed    := 0
DEFAULT cTpSolCf 	:= SuperGetMv("MV_TPSOLCF")                  		//Parametro para validacao do tipo de cliente para o calculo do solidario
DEFAULT nItem       := 0

If nItem > 0 .And. MaFisFound("IT",nItem)
	aLjExcecao := MaFisRet(nItem,"IT_EXCECAO")
	lExcecaoFcl:= Len(aLjExcecao) > 0 
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Verifica a situacao tributaria do item                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SF4->F4_ISS == "S" .AND. ( ( ( SA1->A1_RECISS == "1" .AND. GetNewPar("MV_DESCISS", .F.) ) .OR. ( SA1->A1_RECISS <> "1" ) ) )

	If nALIQISS > 0
		cSitTrib := "S" + AllTrim (Str( nALIQISS,5,2 ))
	Else                                                                                                        
		cSitTrib := "S" + AllTrim (Str( SuperGetMv("MV_ALIQISS"),5,2 ))
	EndIf
	
ElseIf IIF(lF4MKPSOL,SF4->F4_MKPSOL<>"1",.T.) .And. (nPICMRET > 0  .OR. (nPICMENT > 0 .AND. ALLTRIM(SF4->F4_SITTRIB) == "60") .OR.;
		 (lExcecaoFcl .AND. (aLjExcecao[3] > 0 .OR. aLjExcecao[16] > 0 )) );
		.AND. SA1->A1_TIPO $ cTpSolCf .AND. SF4->F4_BSICMST <> 100 
	cSitTrib := "F"										// Substituicao tributaria (Icms Solidario)

ElseIf (SF4->F4_BASEICM > 0 .AND. SF4->F4_BASEICM < 100) .Or. ;
		(lExcecaoFcl .AND. (aLjExcecao[14] > 0) .And. (aLjExcecao[14] < 100))
	
	/*	Aberto um ponto de entrada para que o cliente possa utilizar
		a aliquota de redução que cadastrou na tabela SL4 ao invés de
		utilizar a do SB0	*/
	If !lFtvdVer12 .And. ExistBlock("LJ7017")
		LjGrvLog( Nil, " Antes do PE LJ7017")
		nAliqRed := ExecBlock("LJ7017",.F.,.F.)
		LjGrvLog( Nil, " Retorno do PE LJ7017", nAliqRed)
		lExecPE7017 := .T.
	EndIf
	
	If lFtvdVer12 .And. ExistBlock("FTVD7017")
		LjGrvLog( Nil, " Antes do PE FTVD7017")
		nAliqRed := ExecBlock("FTVD7017",.F.,.F.)
		LjGrvLog( Nil, " Retorno do PE FTVD7017", nAliqRed)
		lExecPE7017 := .T.
	EndIf
	
	If !LExecPE7017 .Or.;
		(LExecPE7017 .And. ((Valtype(nAliqRed) <> "N") .OR. ((nAliqRed <= 0) .Or. (nAliqRed >= 100))))
		
		If LExecPE7017
			LjGrvLog( Nil, " Problema no Ponto de Entrada LJ7017 ou FTVD7017. " +CHR(10)+CHR(13)+;
							" Solução: o retorno do PE deve ser do tipo  Numerico ou o " +;
							" seu retorno não está entre 1 e 99"+CHR(10)+CHR(13)+;
							" Revise o Ponto de Entrada! " +CHR(10)+CHR(13)+;
							" Será efetuado a busca padrão nas tabelas SB0 e SF4", nAliqRed)
		EndIf				
		
		nAliqRed := SB0->B0_ALIQRED	// Considero a alíquota de redução do cadastro de produtos

		// Caso o campo B0_ALIQRED não estiver preenchido e existir excecao fiscal considera o retorno da MaFisRet
		If nAliqRed <= 0 .AND. aLjExcecao[1] > 0
			LjGrvLog( M->LQ_NUM, "Lj7Strib -  Redução de Alíquota não preenchida na campo B0_ALIQRED com isso foi assumido o valor da da exceção fiscal." , nAliqRed) 	
			nAliqRed := aLjExcecao[1]
		EndIf	
		
		//a Exceção Fiscal será maior que qualquer outra regra 
		If lExcecaoFcl
			LjGrvLog( Nil, " Alíquota reduzida configurada como exceção fiscal [ se campo estiver zerado preencha a redução no campo B0_ALIQRED] " , nAliqRed) 		
		Else
			LjGrvLog( Nil, " Alíquota reduzida configurada na TES [campo F4_BASEICM - se alíquota estiver zerada preencha a redução no campo B0_ALIQRED] " , nAliqRed)
		EndIf
	EndIf	
	
	cSitTrib := "T" + AllTrim(Str(nAliqRed,5,2))		// Com redução de Icms na Base de Cálculo do Imposto
	
ElseIf SF4->F4_LFICM == "I"								// Isento

	If ALLTRIM(SF4->F4_SITTRIB) == "41"						
		cSitTrib := "N"
	Else						
		cSitTrib := "I"
	EndIf
	
ElseIf SF4->F4_LFICM == "N" .OR. SF4->F4_LFICM == "O"	// Não sujeito a ICMS

	cSitTrib := "N"
Else													// Com ICMS
	nAliquota := AliqIcms(	"N","S",SA1->A1_TIPO,"I",;
							NIL,.T.)
	cSitTrib := "T" + AllTrim(Str(nAliquota,5,2))
EndIf

Return cSitTrib

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³LJ7DEFFORMºAutor  ³Vendas Clientes     º Data ³  08/08/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Define a string que sera enviada para o ECF para registrar  º±±
±±º          ³a forma de pagamento                                        º±±
±±º          ³Tem que estar com o SL1 posicionado                         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³lTefOk:=Resultada da transacao TEF                          º±±
±±º          ³ExpN1 :=Valor total dos itens                               º±±
±±º          ³ExpN2 :=Valor de acrescimo da venda                    	  º±±  
±±º          ³ExpN3 :=Valor de desconto total da venda                    º±±  
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida                                            º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7DefForm( nValorItem , nAcrescimo, nDesconto , nValSemTef,;
					 nMoedaAtu  , nFatorRes , nFatorVen , nValRes	,;
					 aTaxJuros 	, nVlrServic, nVlrGar	, lNFCeCard )

Local cFormaPgtos	:= "" 					// Retorno da funcao. Retorna as formas de pagto 
Local cFormaPBKP	:= "" 					// Retorno da funcao. Retorna as formas de pagto 
Local aFormaAux		:= {} 					// Array auxiliar que eh alimentada com as formas de pagto
Local nTipoDescri	:= SuperGetMv("MV_LJPAGTO")	// Determina como sera a descricao da forma de pagto
Local nPos			:= 0 					// Variavel auxiliar para busca em strings
Local nPosDescri    := 0					// Posicao da descricao encontrada no array
Local sAdmPgto		:= ""					// Administradora financeira
Local cDescri		:= ""					// Descricao da forma de pagamento
Local cFormRet      := ""					// Forma de pagamento para retencoes de impostos
Local nX			:= 0 					// Variavel para controle de looping
Local nValorIss		:= 0					// Valor do Iss da Venda
Local cOrigem 		:= If(FunName()=="RPC", "LOJA010", FunName()) 	// Origem
Local nVlrTotal		:= If(Funname()$"FRTA271/FRTA010/STIPOSMAIN",SL1->L1_VLRTOT,LJ7T_TOTAL(2))
Local lVlMoed1		:= If(cPaisLoc == "ARG" .AND. SL4->(FieldPos("L4_VLMOED1")) > 0,.T.,.F.)
Local lMoed1Moed4	:= .F.
Local nPosPgto		:= 0 
Local lMoeda1		:= .F.
Local nDecimais  	:= 0
Local nTotFormPag	:= 0
Local lMvLjJurCc	:= SuperGetMv("MV_LJJURCC")	//Verifica se esta habilitado o juros da administradora
Local nGrTotForm 	:= 0					// Valor total das formas de pagamento
Local nFatorServ 	:= 0 					// Fator (Itens de Servico)
Local nFatorProd 	:= 0					// Fator (Itens de Produto)
Local lGE			:= FindFunction("LjUP104OK") .AND. LjUP104OK()	// Validação do Conceito Garantia Estendida 
Local lMvTroco		:= SuperGetMv("MV_LJTROCO",,.F.)
Local nTroco		:=  IIf (nModulo == 12, Lj7T_Troco(2),0)
Local nValor 		:= 0 
Local nFatAcrGar	:= 0					// Fator para proporcionalizar o Acrescimo da garantia extendida
Local nNroItPgto 	:= 0					// Numero de elementos na forma de pagamento
Local lPOS		    := RTrim(Funname()) = "STIPOSMAIN"
Local lAbateISS		:= .F.
Local nValRetenc	:= 0
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()				//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
Local cNomeProg		:= Iif(lFtvdVer12,"FATA701","LOJA701")	//Nome da Rotina
Local lDC			:= .F.					// Debito em Conta - Utilizado em ambiente localizado Argentina

DEFAULT nValorItem  := 0					// Valor total da venda pelos Itens
DEFAULT nAcrescimo	:= 0					// Acrecimo do item
DEFAULT nDesconto   := 0 					// Valor de desconto no total
DEFAULT nValSemTef	:= 0					// Valor da forma de pagamento desconsiderando o TEF
DEFAULT nMoedaAtu	:= 1					// Moeda corrente	
DEFAULT nFatorRes	:= 1
DEFAULT nFatorVen	:= 1
DEFAULT nValRes		:= 0
DEFAULT aTaxJuros	:= {}  
DEFAULT nVlrServic 	:= 0					// Valor dos itens de "Servico"
Default nVlrGar     := 0 					// Valor da Garantia 
Default lNFCeCard	:= .F.					// se utiliza o grupo <card>, separamos a forma de pagamento por administradora financeira

If MaFisFound("NF")
	nValorIss := MaFisRet(,'NF_VALISS')
EndIf
lAbateISS := LJxDAbISS(SL1->L1_CONDPG,SL1->L1_FORMPG,nValorIss)

If nVlrServic > 0
	nFatorServ 	:= (nVlrServic/nVlrTotal) 	//Calcula fator (Itens de Servico)
	nFatorProd 	:= (1-nFatorServ)			//Calcula fator (Itens de Produto)
EndIf

If Type("nMoedaCor") <> "U"
	nDecimais  	:= MsDecimais(nMoedaCor)
Else
	nDecimais  	:= MsDecimais(nMoedaAtu)
EndIf

If Funname()$"FRTA271/FRTA010/STIPOSMAIN"
	nNCCUsada := 0
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Inicializacao das variaveis                                      ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If cGetCliDir == NIL
   cGetCliDir := GetClientDir()
EndIf
If cProfStr1 == NIL
   cProfStr1  := GetPvProfString("Condicao de Pagamento", "Retencoes", "RETENCOES", cGetCliDir+"SIGALOJA.INI")
EndIf 
cFormRet := cProfStr1

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³O sistema vai verificar o parametro MV_LJPAGTO para verificar    ³
//³qual a forma de pagamento sera registrada no ECF. O cliente      ³
//³podera utilizar a descricao da tabela 24 do SX5 ou a descricao   ³
//³cadastrada no arquivo de administradoras (SAE).                  ³
//³Se "1" - Via tabela 24 do SX5, se "2" - Via descricao do SAE     ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If nNCCUsada < nVlrTotal
	DbSelectArea("SL4")
	SL4->(DbSetOrder(1))
	SL4->(DbSeek(xFilial("SL4") + SL1->L1_NUM))
	While !SL4->(Eof()) .AND. SL4->L4_FILIAL + SL4->L4_NUM == xFilial("SL4") + SL1->L1_NUM .AND. Empty(SL4->L4_ORIGEM)
		If lVlMoed1
			lMoed1Moed4 := (SL4->L4_VALOR > SL4->L4_VLMOED1)
		EndIf	
		lMoeda1 := SL4->L4_MOEDA > 1 .AND. lVlMoed1
		If SL4->L4_VALOR > 0
			If lNFCeCard 
				nPos := aScan( aFormaAux, { |x| AllTrim(x[1]) == AllTrim(SL4->L4_FORMA) .AND. x[5] == SL4->L4_FORMAID } )				
			Else 
				nPos := aScan( aFormaAux, { |x| AllTrim(x[1]) == AllTrim(SL4->L4_FORMA) } )
			EndIf

			If (nPos == 0) .OR. (nPos <> 0 .AND. nTipoDescri == 2)
				If !(AllTrim(SL4->L4_FORMA) $ MVCHEQUE + "," + "CR" .OR. IsMoney(SL4->L4_FORMA)) .AND. nTipoDescri == 2
				
					//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
					//³Busca no aPgtos a posicao correspondente ao SL4 ³
					//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
					
					If !lPOS
						nPosPgto := Ascan(aPgtos,{|x| DTOS(x[1])		 + Str(x[2]) 		 + AllTrim(x[3])		  + AllTrim(x[8]) == ;
													  DTOS(SL4->L4_DATA) + Str(SL4->L4_VALOR)+ AllTrim(SL4->L4_FORMA) + AllTrim(SL4->L4_FORMAID)})
	
						If nPosPgto > 0 
							If cPaisLoc == "ARG" .AND.  Len( aPgtos[nPosPgto][4] ) > 12
								If aPgtos[nPosPgto][4][14] == "DC"
									sAdmPgto := aPgtos[nPosPgto][4][13] // Descricao da Forma de pagamento
									lDC := .T.
								Else
									sAdmPgto := aPgtos[nPosPgto][4][5] // Codigo da Forma de Pagamento
								EndIf
							Else

								sAdmPgto := aPgtos[nPosPgto][4][5]

								If  cPaisLoc == "ARG" .AND.  Len( aPgtos[nPosPgto][4] ) <= 12
									LjGrvLog(SL1->L1_NUM,"Atualizar LOJA701B.PRW",)
								EndIf
							EndIF

						EndIf	
					Else
						sAdmPgto := SL4->L4_ADMIN
					EndIf
				EndIf

				 If !(AllTrim(SL4->L4_FORMA)$MVCHEQUE+","+"CR" .OR. IsMoney(SL4->L4_FORMA)) .AND. nTipoDescri == 2 .AND. Len(sAdmPgto)>0
				 	If lDC
						cDescri := AllTrim(sAdmPgto) 	// Descricao do SAE
					Else
						cDescri := AllTrim(Subst(sAdmPgto,7,Len(sAdmPgto)-6)) 	// Descricao do SAE 
					EndIf	
				Else
					cDescri := AllTrim(Tabela("24",AllTrim(SL4->L4_FORMA),.F.))			// Tabela 24
				EndIf

				LjGrvLog(SL1->L1_NUM," Forma de pagamento: " + cDescri,)

				If lNFCeCard
					nPosDescri := aScan( aFormaAux, {|x| AllTrim(x[1]) == AllTrim(SL4->L4_FORMA) .AND. AllTrim(x[2]) == AllTrim(cDescri) ;
					.AND. x[5] == SL4->L4_FORMAID} )
				Else
					nPosDescri := aScan( aFormaAux, {|x| AllTrim(x[1]) == AllTrim(SL4->L4_FORMA) .AND. AllTrim(x[2]) == AllTrim(cDescri)} )
				EndIf

				If nPosDescri == 0 
					If nNCCUsada > 0
						If nValorItem == nVlrTotal .AND. cOrigem == cNomeProg .AND. SL1->L1_TIPO == "P"
							aAdd( aFormaAux, { AllTrim(SL4->L4_FORMA), cDescri, Round( Abs(((If((lMoeda1 .AND. !lMoed1Moed4),SL4->L4_VLMOED1,SL4->L4_VALOR) / nVlrTotal) * nValorItem) - nNCCUsada ), 2 ), SL4->L4_ADMINIS, SL4->L4_FORMAID } )
						Else
							aAdd( aFormaAux, { AllTrim(SL4->L4_FORMA), cDescri, Round( If((lMoeda1 .AND. !lMoed1Moed4),SL4->L4_VLMOED1,SL4->L4_VALOR), 2 ), SL4->L4_ADMINIS, SL4->L4_FORMAID} )
						EndIf				 	
				 	Else
						aAdd( aFormaAux, { AllTrim(SL4->L4_FORMA), cDescri, Round(If((lMoeda1 .AND. !lMoed1Moed4),SL4->L4_VLMOED1,SL4->L4_VALOR),2), SL4->L4_ADMINIS, SL4->L4_FORMAID} )
				 	EndIf
				Else
				   aFormaAux[nPosDescri][3] += If((lMoeda1 .AND. !lMoed1Moed4),SL4->L4_VLMOED1,SL4->L4_VALOR)
				EndIf
			Else
				aFormaAux[nPos][3] += If((lMoeda1 .AND. !lMoed1Moed4),SL4->L4_VLMOED1,SL4->L4_VALOR)
			EndIf
			sAdmPgto := ""
		EndIf
		SL4->( DbSkip() )
	End
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Verifica se foi pago com creditos (NCC)                          ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If SL1->L1_CREDITO > 0 .AND. nNCCUsada > 0
	cDescri := AllTrim(Tabela("24","CR",.F.))			// Tabela 24
	If nValRes > 0
		If nAcrescimo > 0 .AND. nDesconto > 0
			aAdd( aFormaAux, {"CR", cDescri, Round( SL1->L1_CREDITO , 2 ), " ", " "} )
		Else
			aAdd( aFormaAux, {"CR", cDescri, Round( (SL1->L1_CREDITO / nVlrTotal) * (nValorItem - (nDesconto*nFatorVen) + nAcrescimo + nValRes), 2 ), " ", " "} )
		EndIf
	Else
		aAdd( aFormaAux, {"CR", cDescri, Round( (SL1->L1_CREDITO / nVlrTotal) * (nValorItem + nAcrescimo - nDesconto), 2 ), " ", " "} )
	EndIf
EndIf

LjGrvLog(SL1->L1_NUM,"Pagamentos ajustado para o ECF preparar para o ECF",aFormaAux)

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Soma o valor do juros pago no cartao a forma    ³
//³de pagamento cartao de credito                  ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If (lMvLjJurCc) .AND. (Len(aTaxJuros) > 0) .AND. (Len(aFormaAux) > 0)
	If aTaxJuros[2] > 0
		For nX := 1 to Len(aFormaAux)                                                                             
			//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
			//³Varre o array aFormaAux, quando encontrar a forma de pagto CC  ³
			//³soma o valor pago em cartao mais o juros da administradora     ³
			//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ		                                             	
			If aFormaAux[nX][1] $ "CC"
				aFormaAux[nX][3] += aTaxJuros[2]					
			EndIf	
		Next nX            
	EndIf
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Monta a string cFormaPgtos para enviar para o ECF                       ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
aSort(aFormaAux,,,{|x,y| x[3]<y[3]})

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Proporcionaliza o Acrescimo referente a Garantia  nas formas de pagamento³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lGE                   
	nNroItPgto := Len(aFormaAux)  
	If nAcrescimo > 0
		If  nNroItPgto > 0
			nFatAcrGar	:=	( nAcrescimo * nFatorRes ) /  nNroItPgto
	    Endif
	Endif
Endif

aFormaPgtos := {} // limpar por que é chamado na impressao do cupon nao fiscal e depois na impresao do cupom fiscal

For nX := 1 to Len(aFormaAux)
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Calculo da forma de pagamento. ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	// Se houver Itens de "servico" deve ser proporcionalizado. Esta regra se aplica somente quando o parametro MV_LJPRDSV estiver ativo
	If nVlrServic > 0
		nTotFormPag := Round(aFormaAux[nX][3] * nFatorProd,2)
		// Se houver Garantia Estendida deve ser proporcionalizado 
	Elseif lGE .AND. SuperGetMv("MV_LJIMPGF",,.F.) .AND. nFatorVen < 1 .AND. nVlrGar > 0
		nTotFormPag := Round(aFormaAux[nX][3] * nFatorVen,2) + nFatAcrGar
	Else
	    // Se houver Reserva com Retira e se for PdvPaf deve ser proporcionalizado
		nValor := aFormaAux[nX][3]
		
		If nTroco > 0 .AND. nFatorVen < 1 .AND. IsMoney(aFormaAux[nX][1]) .AND.  aFormaAux[nX][3] > nTroco 	  
			nValor := aFormaAux[nX][3] - nTroco 	
		EndIf   
		
		nTotFormPag := IIf (nFatorVen < 1 .AND. lMVLJPDVPA,  NoRound(nValor * nFatorVen,2),nValor)
		If !(nTotFormPag > 0)
			nTotFormPag := 0.01
		EndIf
	EndIf
	
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³ Recalcula 1 centavo na ultima posição de aFormaAux caso ocorra diferença pelas casas decimais. ³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	nGrTotForm += nTotFormPag
	If nX == Len(aFormaAux) .AND. nGrTotForm+If(lAbateISS,nValorIss,0) <> (nValorItem + nAcrescimo - nDesconto) .And. (nNCCUsada > 0 .Or. nFatAcrGar > 0)
		//Quando MV_LJTROCO == .T., pagamento com NCC, pagamento em dinheiro 
		//e se houver um valor de pagamento maior do que o preço da venda ( gerando troco )
		//o troco era subtraido do valor do produto e assim não era emitido no cupom fiscal
		If !( IsMoney(aFormaAux[nX][1]) .AND. lMvTroco .AND. ;
			Abs((nValorItem + nAcrescimo - nDesconto) - nGrTotForm) == nTroco )
			nTotFormPag += ((nValorItem + nAcrescimo - nDesconto) - nGrTotForm)
		EndIf
	EndIf

	If AllTrim( aFormaAux[nX][1] ) $ _FORMATEF	.AND. lHomTef
		cFormaPBKP  +=  Trim(aFormaAux[nX][2]) + "|" + AllTrim(Str(Round(Round(nTotFormPag,3),nDecimais),14,2)) + "|"
	Else
		If lNFCeCard
			cFormaPgtos +=  Trim(aFormaAux[nX][2]) + "|" + AllTrim(Str(Round(Round(nTotFormPag,3),nDecimais),14,2)) + "|" + aFormaAux[nX][4] + "|" + aFormaAux[nX][5] + "|"
		Else
			cFormaPgtos +=  Trim(aFormaAux[nX][2]) + "|" + AllTrim(Str(Round(Round(nTotFormPag,3),nDecimais),14,2)) + "|"

			If AllTrim( aFormaAux[nX][1] ) $ _FORMATEF
				aAdd(aFormaPgtos,{aFormaAux[nX][2],nTotFormPag})
			EndIf	

		EndIf
	EndIf
	
	If !(Trim( aFormaAux[nX][1] ) $ _FORMATEF)
		nValSemTef	+=	Round( aFormaAux[nX][3]	,nDecimais)		// Totalizador das formas diferentes do TEF
	EndIf	

Next nX

If lHomTef
	cFormaPgtos +=	cFormaPBKP
EndIf

If !lAbateISS
	nValorIss := 0
EndIf
nValRetenc := LJPCCRet() + nValorIss // Valor de Retencoes e ISS
If nValRetenc > 0 .AND. !Empty( cFormaPgtos )
	If nFatorProd > 0 .AND. nFatorProd < 1 // Se eh venda mista de RPS e cupom , aplica o fator
		nValRetenc := nValRetenc * nFatorProd
	EndIf	  
	cFormaPgtos += cFormRet + "|" + AllTrim(Str(nValRetenc,14,2)) + "|"
EndIf

LjGrvLog(SL1->L1_NUM,"String de pagamentos completa",cFormaPgtos)
         
Return cFormaPgtos

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7VldAlItºAutor  ³Vendas Clientes     º Data ³  08/10/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Esta funcao valida se o item jah foi impresso. Caso afirma- º±±
±±º          ³tivo nao permite que nenhum campo da aCols seja alterado.   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida Concomitante                               º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7VldAlIt()
Local lRet 			:= .T.		// Retorno da funcao
Local nPosProd 		:= 0		// Posicao do codigo do produto na aCols
Local nPosVlrItem   := 0		// Posicao do valor do item
Local nPosPafMd5	:= 0		// Posicao do PAFMD5, somente possui conteudo quando armazenado no BD
Local lRetagPaf		:= .F.		// Sinaliza retaguarda PAF para validação obrigatorio de DAV/PV
Local lRegDAV		:= !SuperGetMv("MV_LJPRVEN",,.T.)
Local lPDVPOS		:= .F. 
Local lCpoQuant		:= Substr(ReadVar(),4,Len(ReadVar())) == "LR_QUANT"
Local lCpoCodProd	:= Substr(ReadVar(),4,Len(ReadVar())) == "LR_PRODUTO"
//As variáveis lEmitNfce - alimentada pela rotina LjEmitNFCe, lFtvdVer12 - alimentada pela rotina - LjFTVD() e cNomeProg - alimentada pela variável  lFtvdVer12  tiveram seu escopo alterado para variáveis locais, pois o cliente pode mudar de modulo para o SigaFAT através do SIGAADV e essas variáveis mudam o seu valor conforme o módulo
Local lFtvdVer12	:= LjFTVD()	//Verifica se é Release 11.7 e o FunName é FATA701 - Compatibilização Venda Direta x Venda Assisitida
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Inicializa as variaveis                                              ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
nPosProd    := aScan(aHeader,   {|x| AllTrim(Upper(x[2]))=="LR_PRODUTO" })
nPosVlrItem := aScan(aHeader,   {|x| AllTrim(Upper(x[2]))=="LR_VLRITEM" })
nPosPafMd5	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))=="LR_PAFMD5"  })

//PAFECF: Sinaliza Retaguarda PAF-ECF para tratamento do orcamento(DAV/PV)
If LjNfPafEcf(SM0->M0_CGC) .AND. !lFtvdVer12
	//Valida campo obrigatorio no PAF-ECF: "LR_PAFMD5" e realiza tratamento para nao permitir alteracao de item ja armazenado(BD) no Orcamento PAF(DAV ou PV)
	If nPosPafMd5 == 0   
	    If Type("lAutoExec") <> "L" .OR. !lAutoExec	
			MsgAlert(STR0078)		//"Não foi localizado campo: LR_PAFMD5. Obrigatório para utilização do PAF-ECF. Verifique os procedimentos para aplicar o UPDLOJ72"
		Else
			ConOut(STR0078)			//"Não foi localizado campo: LR_PAFMD5. Obrigatório para utilização do PAF-ECF. Verifique os procedimentos para aplicar o UPDLOJ72"
		EndIf
	ElseIf !Empty( aCols[n][nPosProd] ) .AND. aCols[n][nPosVlrItem] > 0 .AND. aColsDet[n][nPosPafMd5] <> Nil                                                                                    
	    lPDVPOS := STDRetagPDV(xFilial("SLG") )
	    
	    If ( (lCpoQuant .Or. lCpoCodProd) .And. !lRegDAV .And. !SL1->L1_IMPNF ) .OR.;
	    ( (lCpoQuant .Or. lCpoCodProd) .And. !lRegDAV .And. !lPDVPOS .And. !SL1->L1_IMPNF )//Conforme ER PAF-ECF 02.01 é permitida alteração de DAV, não permitindo quando Pré-venda
		    If Type("lAutoExec") <> "L" .OR. !lAutoExec	
				MsgStop(STR0079)			//"Conforme previsto nos Requisitos V e VI(Ato COTEPE ICMS 0608), o item registrado no Banco de Dados não pode ser alterado. Se necessário deve-se excluí-lo!"
			Else
				Conout(STR0079)			//"Conforme previsto nos Requisitos V e VI(Ato COTEPE ICMS 0608), o item registrado no Banco de Dados não pode ser alterado. Se necessário deve-se excluí-lo!"
			EndIf	
			lRet := .F.	
		EndIf
	EndIf

	lRetagPaf := !lMVLJPDVPA
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Valida se o produto estah preenchido. Se estiver em branco, significa³
//³ que ainda nao foi enviado para o ECF. Se estiver preenchido, devido  ³
//³ a concomitancia, ele jah foi impresso e nenhuma informacao poderah   ³
//³ ser alterada.                                                        ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If lRet .AND. !lRetagPaf .AND. LjVassConc() .AND. !Empty( aCols[n][nPosProd] ) .AND. aCols[n][nPosVlrItem] > 0
    If Type("lAutoExec") <> "L" .OR. !lAutoExec		
    	MsgAlert( STR0048 ) //O item não pode ser alterado pois já foi registrado no Cupom Fiscal. Se necessário deve-se excluí-lo!
	Else
	    Conout( STR0048 ) //O item não pode ser alterado pois já foi registrado no Cupom Fiscal. Se necessário deve-se excluí-lo!
	EndIf  
	lRet := .F.	
EndIf	

Return lRet

/*ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±ºPrograma  ³Lj7ChkIcm ºAutor  ³ Vendas Clientes    º Data ³  08/10/05   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se a aliquota esta permitida para a impressora     º±±
±±º          ³															  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ Venda Assistida Concomitante                               º±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß*/
Function Lj7ChkIcm( nPerRet, aIcms ) 
Local lRet :=.F.						// Retorno da funcao
Local nElemFiscal						// Posicao da aliquota de ICMS
Local nI   :=1							// Variavel do FOR

Default aIcms 		:= LjSetAliq()

If lFiscal 
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//| Verifica se a aliquota esta no array aIcms previamente carregado     |
	//| com as aliquotas de Icms                                             |
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
	For nI := 1 to Len(aIcms)
		If nPerRet = aIcms[nI][1]
			nElemFiscal := 1
			Exit
		EndIf
	Next nI

	If nElemFiscal == 0 .AND. SF4->F4_ICM == "S"
		
		// A al¡quota de Icms utilizada neste produto n„o est 
		// cadastrada na Impressora fiscal. utilize a op‡„o adiciona Aliquota
		// no menu Miscelƒnea, M¢dulo fiscal, para cadastr -la na Impressora.
		// a al¡quota n„o cadastrada ‚ :
		// Aten‡„o
		If Type("lAutoExec") <> "L" .OR. !lAutoExec		
			MsgStop(	STR0041	+ STR0042 +	STR0043 +	;
						STR0044 + Transform(If(SB0->B0_ALIQRED>0,SB0->B0_ALIQRED,nPerRet),"@E 99.99") + "%",;
						STR0045	)
		Else
			Conout(		STR0041	+ STR0042 +	STR0043 +	;
						STR0044 + Transform(If(SB0->B0_ALIQRED>0,SB0->B0_ALIQRED,nPerRet),"@E 99.99") + "%",;
						STR0045	)
		EndIf
		nPerRet := 0
	Else
	    // Aliquota valida no ECF
	    lRet:=.T.
	   	
	EndIf
	
EndIf

Return lRet
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LjRWriteLoºAutor  ³Vendas Clientes     º Data ³  27/12/2004 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Função criada para a gravação dos Logs do restaurante      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LjRWriteLog( cArq, cTexto )
Local nHandle 	:= 0										// Handle do resultado da abertura do arquivo
Local cPath 	:= "\AUTOCOM\RES"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ","")+"\"		// Caminho para o LOG

cArq := cPath + cArq

If !File(cArq)
	MakeDir("\AUTOCOM")
	MakeDir("\AUTOCOM\RES"+cEmpAnt+StrTran(Alltrim(cFilAnt)," ",""))
	nHandle := FCreate( cArq )
	FClose(nHandle)
EndIf
If File(cArq)
	nHandle := FOpen( cArq, 2 )
	FSeek ( nHandle, 0, 2 )											// Posiciona no final do arquivo
	FWrite( nHandle, cTexto + Chr(13) + Chr(10), Len(cTexto)+2 )
	FClose( nHandle) 
EndIf

Return NIL
/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7SomaItemºAutor  ³Vendas CLientes     º Data ³  04/05/07   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Soma o valor total dos itens                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Retorna o valor total dos itens                             º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701D                                                    º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Static Function Lj7SomaItem()

Local nI 		:= 0											// Variavel do FOR
Local nSomaIt	:= 0											// Guarda o valor dos Itens			
Local nPos		:= Ascan(aHeader, { |X| X[2] ="LR_VLRITEM" }  )	// Posicao do valor do item
Local nPosItem	:= Ascan(aHeader, { |X| X[2] ="LR_ITEM"    }  )	// Posicao do item
Local nPosProd	:= Ascan(aHeader, { |X| X[2] ="LR_PRODUTO" }  ) // Posicao do codigo do produto
Local nPosGaran	:= Ascan(aHeader, { |X| X[2] ="LR_GARANT"  }  )	// Posicao do codigo do produto garantia estendida
Local nPosItGar	:= Ascan(aHeader, { |X| X[2] ="LR_ITEMGAR" }  ) // Posicao do item garantia estendida
Local cProdGar	:= ""
Local cItemGar	:= ""
Local lGE		:= FindFunction("LjUP104OK") .And. LjUP104OK() .And. nPosItGar > 0 .And. nPosGaran > 0 .And. SuperGetMV("MV_LJIMPGF",,.T.)	// Validação do Conceito Garantia Estendida 

For nI := 1	To Len(aCols)
	If !aCols[nI, Len(aCols[nI])]
		If !lGE .Or. (!(cProdGar == aCols[nI, nPosProd]) .And. !(cItemGar ==  aCols[nI,nPosItem]))
			nSomaIt += aCols[nI, nPos]
		EndIf
	EndIf
	If lGE
	   cItemGar := aCols[nI,nPosItGar]
	   cProdGar := iIf(Type("aCols["+AllTrim(STR(nI))+","+AllTrim(STR(nPosGaran))+"]") # "U" , aCols[nI,nPosGaran], "")
	EndIf
Next nI
Return(nSomaIT)

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |Lj7ImpBrd ºAutor  ³Vendas              º Data ³  11/12/08   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Alimenta aCols e aColsDet com dados dos Brindes e          º±±
±±º          ³ efetua impressao dos mesmos                                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ LOJA701D                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7ImpBrd()
Local nNumItem		:= 0									    //Numero do Item
Local aNImp         := {}										//Array que contem o número dos itens que serão impressos.
Local nX			:= 1										// Variavel de controle de LOOP
Local aColsBrd		:= Array(Len(aPosCpo)	+ 1)								//Array com os dados dos brindes
Local aColsBDet   	:= Array(Len(aPosCpoDet)	+ 1)								//Array com os dados Detalhes dos brindes

Local nPosItem 		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_ITEM"})][2]			// Posicao da coluna Item
Local nPosProd		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_PRODUTO"})][2]		// Posicao da codigo do produto
Local nPosDescri	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_DESCRI"})][2]		// Posicao da Descricao do produto
Local nPosQuant		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_QUANT"})][2]			// Posicao da Quantidade
Local nPosVlUnit	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_VRUNIT"})][2]		// Posicao do Valor unitario do
Local nPosVlItem	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_VLRITEM"})][2]		// Posicao do Valor do item
Local nPosUM		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_UM"})][2]			// Posicao da UM
Local nPosDesc		:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_DESC"})][2]	 		// Posicao do percentual de desconto
Local nPosValDsc	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_VALDESC"})][2]		// Posicao do valor de desconto
Local nPosEntreg	:= aPosCpo[Ascan(aPosCpo,{|x| AllTrim(Upper(x[1]))	== "LR_ENTREGA"})][2]		// Posicao da Entrega

Local nPosDtItem	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_ITEM" })
Local nPosProdDt	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_PRODUTO" })
Local nPosTes		:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_TES" })
Local nPosCF		:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_CF" })
Local nPosBIcm		:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_BASEICM" })
Local nPosValIcm	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_VALICM" })
Local nPosValIpi	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_VALIPI" })			// Posisacao do campo IPI
Local nPosValIss	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_VALISS" })
Local nPosTabela	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_TABELA" })
Local nPosDescPr	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_DESCPRO" })
Local nPosPrctab	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_PRCTAB" })
Local nPosFrete		:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_VALFRE" })
Local nPosSeguro	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_SEGURO" })
Local nPosDespes	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_DESPESA" })
Local nPosReserv	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_RESERVA" })
Local nPosLojaRe	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_LOJARES" })
Local nPosOrcRes	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_ORCRES" })
Local nPosEmpres	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_EMPRES" })
Local nPosFilRes	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_FILRES" })
Local nPosLocal		:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_LOCAL" })  
Local nPosNSerie	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_NSERIE" })   
Local nPosLotCtl	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_LOTECTL" })
Local nPosNLote		:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_NLOTE" })  
Local nPosLocali	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_LOCALIZ" })  
Local nPosDtVali	:= aScan(aposCpoDet,{|x| AllTrim(Upper(x[1]))		== "LR_DTVALID" })  

DbSelectArea("SL2")
DbSetOrder(1)              //Filial + orçamento + item +produto
DbSeek(xFilial("SL2")+SL1->L1_NUM)
While !Eof() .AND. SL2->L2_FILIAL+SL2->L2_NUM == xFilial("SL2")+SL1->L1_NUM
	nNumItem ++
	If SL2->(FieldPos("L2_PREMIO")) > 0 .AND. SL2->L2_PREMIO == "1"
		
		If nPosItem > 0
			aColsBrd[nPosItem]			:=	SL2->L2_ITEM
		EndIF
		
		If nPosProd > 0
			aColsBrd[nPosProd]			:=	SL2->L2_PRODUTO
		EndIf
		
		If nPosDescri > 0
			aColsBrd[nPosDescri]		:= 	SL2->L2_DESCRI
		EndIf
		
		If nPosQuant > 0
			aColsBrd[nPosQuant]			:= 	SL2->L2_QUANT
		EndIf
		
		If nPosVlUnit > 0
			aColsBrd[nPosVlUnit]		:= 	SL2->L2_VRUNIT
		EndIf
		
		If nPosVlItem > 0
			aColsBrd[nPosVlItem]		:= 	SL2->L2_VLRITEM
		EndIf
		
		If nPosUM > 0
			aColsBrd[nPosUM]			:= 	SL2->L2_UM
		EndIf
		
		If nPosDesc > 0
			aColsBrd[nPosDesc]			:=	SL2->L2_DESC
		EndIf
		
		If nPosValDsc > 0
			aColsBrd[nPosValDsc]		:=	SL2->L2_VALDESC
		EndIF
		
		If nPosEntreg > 0
			aColsBrd[nPosEntreg]		:= 	SL2->L2_ENTREGA
		EndIf

       	aColsBrd[Len(aColsBrd)]		:= .F.

		AADD( aCols , aColsBrd)
				
		If nPosDtItem > 0
			aColsBDet[nPosDtItem]			:=  SL2->L2_ITEM
		EndIf
		
		If nPosProdDt > 0
			aColsBDet[nPosProdDt]		:=	SL2->L2_PRODUTO
		EndIf
		
		If nPosTes > 0
			aColsBDet[nPosTes]			:=	SL2->L2_TES
		EndIf
		
		If nPosCF > 0
			aColsBDet[nPosCF]			:=	SL2->L2_CF
		EndIf
		
		If nPosBIcm > 0
			aColsBDet[nPosBIcm]			:=	SL2->L2_BASEICM
		EndIF
		
		If nPosValIcm > 0
			aColsBDet[nPosValIcm]		:=	SL2->L2_VALICM
		EndIf
		
		If nPosValIpi > 0
			aColsBDet[nPosValIpi]		:=	SL2->L2_VALIPI
		EndIf
		
		If nPosValIss > 0
			aColsBDet[nPosValIss]		:=	SL2->L2_VALISS
		EndIf
		
		If nPosTabela > 0
			aColsBDet[nPosTabela]		:=	SL2->L2_TABELA
		EndIf
		
		If nPosDescPr > 0
			aColsBDet[nPosDescPr]		:=	SL2->L2_DESCPRO
		EndIF
		
		If nPosPrctab > 0
			aColsBDet[nPosPrctab]		:=	SL2->L2_PRCTAB
		EndIF
		
		If nPosFrete > 0
			aColsBDet[nPosFrete]		:=	SL2->L2_VALFRE
		EndIF
		
		If nPosSeguro > 0
			aColsBDet[nPosSeguro]		:=	SL2->L2_SEGURO
		EndIf
		
		If nPosDespes > 0
			aColsBDet[nPosDespes]		:=	SL2->L2_DESPESA		
		EndIf
		
		If nPosReserv > 0
			aColsBDet[nPosReserv]		:=	SL2->L2_RESERVA
		EndIf
		
		If nPosLojaRe > 0
			aColsBDet[nPosLojaRe]		:=	SL2->L2_LOJARES
		EndIf
		
		If nPosOrcRes > 0
			aColsBDet[nPosOrcRes]		:=	SL2->L2_ORCRES
		EndIf
		
		If nPosEmpres > 0
			aColsBDet[nPosEmpres]		:=	SL2->L2_EMPRES
		EndIf
		
		If nPosFilRes > 0
			aColsBDet[nPosFilRes]		:=	SL2->L2_FILRES
		EndIf
		
		If nPosLocal > 0
			aColsBDet[nPosLocal] 		:=	SL2->L2_LOCAL
		EndIF
		
		If nPosNSerie > 0
			aColsBDet[nPosNSerie]		:=	SL2->L2_NSERIE
		EndIf
		
		If nPosLotCtl > 0
			aColsBDet[nPosLotCtl]		:=	SL2->L2_LOTECTL
		EndIf
		
		If nPosNLote > 0
			aColsBDet[nPosNLote] 		:=	SL2->L2_NLOTE
		EndIf
		
		If nPosLocali > 0
			aColsBDet[nPosLocali]		:=	SL2->L2_LOCALIZ
		EndIF
		
		If nPosDtVali > 0
			aColsBDet[nPosDtVali]		:=	SL2->L2_DTVALID
		EndIf
		
       	aColsBDet[Len(aColsBDet)]	:= .F.																										

		AADD( aColsDet , aColsBDet)
    	
    	AADD(aNImp , nNumItem )    
	
	EndIf
DbSkip()
End

For nX := 1 to Len( aNImp )
	LJ7ImpItCC( aNImp[nX] , aCols )
Next nX

Return Nil


/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |LJ7DImpCpfºAutor  ³Microsiga           º Data ³  08/20/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Retorna se foi impresso CPF/CNPj no Cupom                  º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/        

Function LJ7DImpCpf()
Local lRet	:= lImpCpfNpj

lImpCpfNpj	:= .F.

Return lRet  

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |Lj701DVECFºAutor  ³Vendas CRM          º Data ³  08/20/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Recalcula os Valores unitario, desconto e valor do item    º±±
±±º          ³ para que seja o mesmo calculo utlizado no Loja701A         º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function Lj701DVECF(cDesconto,cVrUnit,cVlrItem )

cVrUnit   := AllTrim( Str(A410Arred(SL2->L2_PRCTAB,"D2_PRCVEN") ) )
cDesconto := AllTrim( Str( SL2->L2_VALDESC ) )
cVlrItem  := AllTrim( Str( A410Arred(SL2->L2_PRCTAB * SL2->L2_QUANT,"D2_PRUNIT") ) ) 

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7ImpLoc   ºAutor³Vendas CRM			 º Data ³  10/06/11   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Impressao localizada para documentos fiscais e nao fiscais  º±±
±±º		     ³Release 11.5 - Controle de Formularios - F2CHI			  º±±
±±º		     ³Paises: Chile /Colombia 		        					  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpL1:=LJXVldFo(ExpC1,ExpC2,ExpC3,ExpC4,ExpC5,ExpC6,@ExpN7) º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpA1 - Array com a quebra da venda em mais de uma factura  º±±
±±º			 ³ExpA2 - Array com os dados do comprovante de venda.		  º±±
±±º			 ³ExpN3 - Tipo de operacao 									  º±±
±±º			 ³ExpL4 - Indica se imprime documento nao fiscal			  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ExpL1 - Indica se o formulario eh valido	 				  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/  
Function Lj7ImpLoc (aBreakFis,aRetCNF,nOpc,lNFis)

Local lCFolLocR5:=	SuperGetMv("MV_CTRLFOL",,.F.)  .AND. cPaisLoc$"CHI|COL" .AND. !lFiscal
Local lImpTk	:= 	FindFunction("LjxBGetNf") .AND. LjxBGetNf()
Local lRet			:= .F.   
Local nY			:= 0
Local cljcupnfis	:= SuperGetMv("MV_SCRCUP",,.F.)

Default aBreakFis := {} 
Default aRetCNF	:= {}
Default nOpc		:= 3 
Default lNFis		:= .F.

If !lCFolLocR5 .AND. !lImpTk  
	Return lRet
EndIf


//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Venda por excecao³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If LjProfile(28)
	Return lRet
EndIf

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Quando a impressao da venda for "quebrada" em mais de um formulario,porque³
//³o numero de itens de venda excedeu o limite, executar a funcao LOJR110    ³
//³para cada nota emitida.                                                   ³
//³Este trecho consulta todos os itens da venda na tabela SL2 e faz a        ³
//³divisao dos itens por formulario.Esta divisao fica no array aBreakNota	 ³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ       
    
If lImpTk
	If ExistBlock(cljcupnfis)
		ExecBlock(cljcupnfis,.F.,.F.)
	Else
		lRet := .F.	
		Alert("Função ")
	EndIf
ElseIf Len(aBreakFis)   > 0
	//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
	//³Impressao do documento fiscal (Factura / Boleta)³
	//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
   		For nY:=1 To Len(aBreakFis)									
		If Len(aBreakFis[nY][3]) > 0
			LjMsgRun(STR0066 + aBreakFis[nY][1],,{ || lRet := LojR110( aBreakFis[nY][1], aBreakFis[nY][2], NIL,aBreakFis[nY]) } )	 //"Aguarde... Imprimindo."
		EndIf
	Next nY	
Else
	lNFis := .T.
EndIf
//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³Impressao do comprovante de venda³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ		
If lNFis .AND. nOpc == 3 .AND. Len(aRetCNF) > 0
	If ExistBlock("SCRPED")
		LjMsgRun(STR0066 + aRetCNF[2][1],,{ ||lRet:=  ExecBlock("SCRPED", .F., .F., {aRetCNF[2][1],aRetCNF[2][3]})})
	EndIf			
                           
EndIf
			 
Return lRet				

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |Lj701DSLK ºAutor  ³Vendas CRM          º Data ³  08/20/09   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica slk                                                º±±
±±º          ³                                                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj701DSLK(cCodProd,cCodBar,MvCodBar)

Local cTabela := ""							// Tabela

Default cCodProd := ""
Default cCodBar := ""
Default MvCodBar := "N"

If nModulo == 12 
	cTabela := "SB1"
Else
	cTabela := "SBI"
EndIf

bPrefixo := { |x| &(cTabela + "->" + SubStr(cTabela,2,2) + x ) }

If MvCodBar == "S"
	SLK->(DbSetOrder(2))
	If SLK->(DbSeek( xFilial("SLK") + cCodProd ))
		cCodProd := SLK->LK_CODBAR
	ElseIf !Empty(cCodBar)
		cCodProd := cCodBar
	EndIf
EndIf

Return cCodProd

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  |Lj7CFImpreºAutor  ³Vendas CRM          º Data ³  02/08/11   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se o cupom fiscal esta fechado.                    º±±
±±º          ³lRet == .T. > Cupom deve ser efetivado                      º±±
±±º          ³lRet == .F. > Cupom deve ser cancelado                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SIGALOJA                                                   º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function Lj7CFImpreso(lCancelamento)
Local lRet		:= .F. 													// Retorno da funcao
Local lTentar	:= .T.													// Tentar novamente?
Default lCancelamento := .F.											// Teste de cancelamento de cupom

//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
//³ Tratamento especifico para Hasar, onde a comunicacao com o ECF é testada.	³
//³ Se comunicar, saberemos que a impressão do cupom foi concluída. 			³
//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
If !lCancelamento .AND. "HASAR" $ LJGetStation("IMPFISC")
	While !lRet .AND. lTentar
		lRet := (IFStatus( nHdlECF, '17', '' ) == 0)					// Consulta de estado da impressora para testar comuinicação com o ECF
		If !lRet
			lTentar := MsgYesNo(STR0067 + Chr(10) + Chr(13) + STR0068) // A impressora fiscal não responde! _ Deseja tentar novamente?
			If !lTentar
				lTentar := !(MsgYesNo(STR0069)) 						// 'O cupom fiscal será cancelado. Tem certeza?'
			EndIf
		EndIf
	End
Else
	lRet := MsgYesNo(STR0064) 											// "Cupom impresso corretamente ?"
EndIf

Return lRet 



//--------------------------------------------------------
/*{Protheus.doc} ChkIncICMS
Verifica se havera incidencia de ICMS para acrescimo financeiro.

@author  Leandro F. Dourado
@version P11.5
@since   09/11/2012
@return	 Verdadeiro caso haja incidencia de ICMS no acrescimo financeiro. Falso caso não haja.
*/
//--------------------------------------------------------
 
Function ChkIncICMS()

Local aArea		:= GetArea()							// Guardo a area
Local lRet 		:= .T.									// Retorno da funcao
Local lLjIcmJr	:= cPaisLoc == "BRA" .AND. SuperGetMV("MV_LJICMJR",,.F.)	//Nao incide ICMS sobre a BC
Local cFormPag	:= SL1->L1_FORMPG						// Forma de pagamento da venda
Local cCondPag	:= SL1->L1_CONDPG						// Condicao de pagamento da venda
Local aSl4Ord	:= {}

If lLjIcmJr
    If AllTrim(cCondPag) == "CN"

		aSl4Ord := SL4->(GetArea())
		SL4->(DBSetOrder(1))
		SL4->(DBSeek(xFilial("SL4")+SL1->L1_NUM))
		While SL4->(!EOF()) .And. SL4->(L4_FILIAL+L4_NUM) == SL1->(L1_FILIAL+L1_NUM)
			If AllTrim(SL4->L4_FORMA) == "FI" .And. SL4->L4_ACRSFIN > 0
				lRet := .F.
				Exit
			EndIf
			Sl4->(DBSkip())
		End
		RestArea(aSl4Ord)   

	ElseIf cFormPag == "FI" .And. SE4->(DbSeek(xFilial("SE4")+cCondPag))
		If (SE4->E4_ACRSFIN > 0) .AND. SE4->E4_AGRACRS == "2"
			lRet := .F.
		EndIf
	EndIf
EndIf

RestArea(aArea)

Return lRet



//--------------------------------------------------------
/*{Protheus.doc} lj7GetForm
guardara o rateio da das formas de pagamento no valor do cupom fiscal

@author  Roberto B. Melo
@version P11.5
@since   25/09/2015
@return	 aFormaPgtos
*/
//--------------------------------------------------------
Function lj7GetForm()
 
Return aFormaPgtos


//--------------------------------------------------------
/*{Protheus.doc} lj7SetForm
Limpa a estatica 

@author  Roberto B. Melo
@version P11.5
@since   25/09/2015
@return	 
*/
//--------------------------------------------------------
Function lj7SetForm()

aFormaPgtos := {} 

Return 


//--------------------------------------------------------
/*{Protheus.doc} LjDscCESCF
Retorno da Descrição CEST no CF Fiscal segundo legislação
CONVÊNIO ICMS 25, DE 8 DE ABRIL DE 2016

@param1	 cDescricao Descricao do produto 
@param2	 nItem	referencia do item para acesso a MatxFis
@author  Varejo
@version P11.80
@since   07/06/2016
@return	 cRet Descrição ajustada para legislação
*/
//--------------------------------------------------------
Function LjDscCESCF(cDescricao,nItem,cCest)
Local cRet		:= ""
Local cITcEst	:= ""
Local cB1PosIpi := ""

Default cCest   := ""

cRet := cDescricao

/*  CONVÊNIO ICMS 25, DE 8 DE ABRIL DE 2016
	#código CEST#NCM/SH#descrição do item */
If lMVLJPDVPA
	//Informações são chamadas no momento da impressão portanto já esta tudo posicionado
	If Empty(cCest)
    	cITcEst		:=  AllTrim(MaFisRet(nItem,'IT_CEST'))
	Else
        cITcEst     :=  AllTrim(cCest)
	EndIf
    
    cB1PosIpi   :=  AllTrim(SB1->B1_POSIPI)
    
    If !Empty(cITcEst) .And. !Empty(cB1PosIpi)
        cRet := "#" + cITcEst + "#" + cB1PosIpi + "#" +  AllTrim(cRet)
        cRet := Substr(cRet,1,200)
    EndIf
EndIf

Return cRet

//--------------------------------------------------------
/*{Protheus.doc} LjPrtTEFCan
Realiza a impressão do cancelamento do TEF

@param1	oTef - Objeto TEF
@param2	cPDV - Codigo do PDV
@param3	cDoc - Documento da venda
@param4	cSerie - Serie da venda
@author	Varejo
@version	P11.80
@since		20/06/2016
@return	lRet =	.T. Impresso o comprovante com sucesso / 
					.F. -> Nao impresso o comprovante
*/
//--------------------------------------------------------
Function LjPrtTEFCan(oTef, cPDV, cDoc, cSerie)
Local lRet		:= .F.
Local nRetorno	:= 1
Local nI		:= 0
Local cLinha	:= Replic("=", 35)
Local cCrLf		:= Chr(10)
Local lGuil		:= SuperGetMV("MV_FTTEFGU",,.T.)					// Ativa guilhotina
Local nSaltoLn	:= SuperGetMV("MV_FTTEFLI",,1)						// Linha pula entre comprovante
Local lEmitNfce	:= LjEmitNFCe()		// Sinaliza se utiliza NFC-e ?
Local lPOS		:= STFIsPOS()		// POS (TOTVS PDV) ?
Local cTexto	:= ""												// Mensagem de cancelamento

Default oTef	:= Nil
Default cPDV	:= ""
Default cSerie	:= ""

If lEmitNfce

	cTexto +=	AllTrim(SM0->M0_NOMECOM) + cCrLf 											//Denominação
	cTexto +=	AllTrim("CNPJ:" + SM0->M0_CGC + " / IE:" + SM0->M0_INSC) + cCrLf		//CNPJ //Inscrição Estadual
	cTexto +=	AllTrim(SM0->M0_ENDENT) + " - "	+ cCrLf + ;								//Endereco
				AllTrim(SM0->M0_BAIRENT)+ " - "	+;											//Bairro
				AllTrim(SM0->M0_CIDENT) + " - "	+;											//Cidade
				AllTrim(SM0->M0_ESTENT) + cCrLf												//Estado
	cTexto += cLinha	+ cCrLf
	cTexto += STR0093	+ cCrLf					//"         CANCELAMENTO TEF"
	cTexto += cLinha	+ cCrLf
	
	If !Empty(cDoc)
		cTexto += STR0090 + cDoc		+ cCrLf	//Doc. Venda  :
	EndIf
	If !Empty(cSerie)
		cTexto += STR0091 + cSerie	+ cCrLf	//Serie :
	EndIf
	If !Empty(cPDV)
		cTexto += STR0092 + cPDV		+ cCrLf	//PDV   :
	EndIf
	
	For nI := 1 To Len(oTef:aRetCartao)
		cTexto += cLinha + cCrLf
		cTexto += STR0094		+ AllTrim(oTef:aRetCartao[nI]:cDescAdm)	+ cCrLf		//Adm:
		cTexto += STR0095 	+ AllTrim(oTef:aRetCartao[nI]:cDescCart)	+ cCrLf		//Desc.:
		cTexto += STR0096		+ dToC(oTef:aRetCartao[nI]:dDataTrans)		+ cCrLf		//Data:
		cTexto += STR0097		+ Time()										+ cCrLf		//Hora:
		cTexto += STR0098		+ AllTrim(oTef:aRetCartao[nI]:cAutoriza)	+ cCrLf		//Aut:
		cTexto += "CV    : "	+ AllTrim(oTef:aRetCartao[nI]:cNSUAutor)	+ cCrLf		//CV:
	
		cValor := AllTrim(Str(oTef:aRetCartao[nI]:nVlrTrans))
		If !("." $ cValor)
			cValor += ".00"
		ElseIf Len(SubStr(cValor,Rat(".",cValor)+1)) == 1
			cValor += "0"
		EndIf
		
		cTexto += STR0099	+ cValor + cCrLf		//"Valor Cancelado: R$ "
		cTexto += cLinha	+ cCrLf
	Next nI
	
	cTexto += Replic(cCrLf,5)
	
	Replic(cCrLf,nSaltoLn) //Salta linha extra

	If lGuil //Corte de Papel
		cTexto += TAG_GUIL_INI+TAG_GUIL_FIM
	Endif

	If !lPOS
		nRetorno := INFTexto(cTexto)
	Else
		nRetorno := STWPrintTextNotFiscal(cTexto)
	Endif

EndIf

lRet := (nRetorno == 0)

Return lRet

//----------------------------------------------------------------
/*/{Protheus.doc} LjDefColun
Define as colunas, tamanho e alinhamento a serem utilizados para impressao dos ites da venda.
@param		nQtdColuna		Quantidade de Colunas suportada pela impressora.
@return	aRet			Retorna um array com as definicoes das colunas a serem utilizadas para impressao dos ites da venda.
@author	Varejo
@version	P11.8
@since		03/05/2016
/*/
//------------------------------------------------------------------
Function LjDefColun( nQtdColuna )

Local aColunas 	:= {}	
Local cSeparCol 	:= " "	//Caracter separador de colunas (1 espaco vazio)
Local nInd 		:= 0	
Local nQtdColUsa	:= 0	//Quantidade de Colunas utilizadas
Local nQtdColRes	:= 0 	//Quantidade de Colunas Restantes
Local xTamanho	:= Nil	
Local aColAuto	:= {} 	//Colunas auto-dimensionaveis
Local nLenColuns	:= 0	
Local nPos	 		:= 0	
Local lUseSat		:= 	IIF(FindFunction("LjUseSat"),LjUseSat(),.F.)  //Utiliza SAT

//Descricao das Colunas e Seus respectivos tamanhos, para impressao dos itens da venda.
//Apenas a "Descricao" sera auto-dimensionavel, as demais colunas terao seu tamanho fixo (pre-definido).

If !lUseSat
	aColunas := {	{ "Codigo"	, "Descricao"	, "Qtd"	,  "Un"	,	"VlUnit."	,	"VlTotal"	} ,; 	//Descricao das Colunas
					{	15		, 		Nil		,	07		,	02		,	08			,	09	 		} ,; 	//Tamanho das Colunas
					{ 	"L"		, 		"L"		,	"R"		,	"L"		,	"R"			,	"R"			} }	 	//Alinhamento do conteudo das Colunas (L=Left; R=Right; C=Center)
Else
	aColunas := {	{ "#"	,	"COD"	,	"DESC"	,	"QTD"	,	"UN"	,	""	,	"VL UN R$"	,	"VL ITEM R$"	} ,; 	//Descricao das Colunas
					{ 03	,	15		,	Nil		,	05		,	02		,	01	,	08			,	08				} ,; 	//Tamanho das Colunas
					{ "L"	,	"L"		,	"L"		,	"R"		,	"L"		,	"R"	,	"R"			,	"R"				} }	 	//Alinhamento do conteudo das Colunas (L=Left; R=Right; C=Center)
EndIf					

nLenColuns := aColunas[1]

For nInd:=1 To Len(nLenColuns)
	
	xTamanho 	:= aColunas[2][nInd]
	
	If xTamanho == Nil //Tamanho a ser definido
		aAdd( aColAuto, nInd )
	Else
		nQtdColUsa += xTamanho + Len(cSeparCol)
	EndIf

Next nInd

nQtdColRes := nQtdColuna - nQtdColUsa

//Verifica se tem colunas auto-dimensionaveis
If Len(aColAuto) > 0
	
	xTamanho := nQtdColRes //Define o tamanho da coluna
	
	If xTamanho <= 0
		xTamanho := 1
	EndIf
	
	//Percorre o array aColAuto para ajustar as colunas que sao auto-dimensionaveis.
	For nInd:=1 To Len(aColAuto)
		nPos 	:= aColAuto[nInd]
		
		aColunas[2][nPos] := xTamanho
	Next nInd
	
EndIf

Return aColunas

//----------------------------------------------------------------
/*/{Protheus.doc} LjPrintIt
Retorna a linha formatada do Cabecalho dos Itens ou do Item a ser impresso.
@param	 aCabecalho		Array com as informacoes Cabeçalho.
@param	 aTamCols			Array com o Tamanho das Colunas a serem impressas dos itens da venda.
@param	 aAlignCols		Array com o Alinhamento Colunas a serem aplicados.
@param	 aPrintItem		Array com as informacoes a serem impressas na linha
@param	 nQtdColuna		Quantidade de Colunas suportada pela impressora.
@param	 cTagIniLin		TAG Inicial para formatacao da linha a ser impressa.
@param	 cTagFimLin		TAG Final para formatacao da linha a ser impressa.
@return	 cLinhaRet		Retorna a linha formatada a ser impressa.
@author  Varejo
@version P11.8
@since   03/05/2016
/*/
//------------------------------------------------------------------
Function LjPrintIt( aCabecalho, aTamCols, aAlignCols, aPrintItem,;
 					nQtdColuna, cTagIniLin, cTagFimLin, lCabecalho )
Local cLinhaRet	:= ""
Local cCrLf		:= Chr(10)
Local cCharSepar:= " "			//Caracter separador de colunas (1 espaco vazio)
Local nInd		:= 0
Local nQtdColUsa:= 0 			//Quantidade de Colunas utilizadas
Local cConteudo	:= ""
Local nTamanho	:= 0
Local nTamOrig	:= 0 			//Tamanho Original da Coluna
Local cAlign	:= ""
Local cEspacoIni:= "" 			//Espaco inicial da linha quando pular para a proxima linha devido a descricao do produto nao caber na mesma linha
Local cDescCabec:= ""			//Coluna do cabeçalho
Local cPula	 	:= ""			//Coluna do cabeçalho
Local lMVLJCONDE:= SuperGetMV("MV_LJCONDE",,.F.)	//Define se utilizar condensado ou não
Local lPOS		:= STFIsPOS() //Pos?
Local cModelo	:= IIF(lPOS,STFGetStation("IMPFISC"),FTVDGetStation("IMPFISC")) // modelo impressora
Local cDescrPro := ""

Default lCabecalho := .F.

If lCabecalho
	cCharSepar := "|"
EndIf

For nInd:=1 To Len(aCabecalho)
	
	cDescCabec	:= AllTrim(aCabecalho[nInd])
	If lCabecalho
		cConteudo 	:= cEspacoIni + AllTrim(aCabecalho[nInd])
	Else
		cConteudo 	:= cEspacoIni + AllTrim(aPrintItem[nInd])
	EndIf	
	nTamOrig:= aTamCols[nInd]
	nTamanho:= nTamOrig + Len(cEspacoIni)
	cAlign 	:= aAlignCols[nInd]
	cPula	:= ""
	
	//Trata tamanho da Descricao do Produto
	If !lCabecalho .And. "DESC" $ UPPER(cDescCabec)  //Coluna da DESCRICAO DO PRODUTO
		
		//Ajusta o tamanho da coluna de descricao do produto (Espaco definido para impressao da descricao do produto).
		//Se a Descricao do Produto for maior que o espaco disponivel para impressao na mesma linha, sera impresso o codigo e a descricao em uma 
		//linha soh, e os outros campos na linha seguinte, caso contrario, todas as informacoes sao impressas em uma linha unica.
		nTamanho 	:= nQtdColuna - nQtdColUsa //Calcula a quantidade de colunas restantes disponivel para impressao na linha.
		
		//tratamento realizado por motivo do espaçamento da daruma ser diferente da bematech
		If lMVLJCONDE .Or. "BEMATECH" $ cModelo  
			cEspacoIni	:= Space(nQtdColUsa + nTamOrig + Len(cCharSepar)) //Adiciona espacos iniciais da linha seguinte.
		Else	
			cEspacoIni	:= Space(nQtdColUsa) //Adiciona espacos iniciais da linha seguinte.
		EndIf
		
		cPula	:= cCrLf

		cDescrPro 	:= Substr(cConteudo,nTamanho+1,Len(AllTrim(AllTrim(cConteudo))))		

	Else
		cEspacoIni	:= cCharSepar	
	EndIf

	nQtdColUsa += nTamOrig + Len(cCharSepar)
	
	While !Empty(cConteudo)
		Do Case
			Case cAlign == "L" //LEFT (Conteudo Alinhado a Esquerda)
			
				cConteudo := PadR(cConteudo, nTamanho)
				
			Case cAlign == "R" //RIGHT (Conteudo Alinhado a Direita)
			
				cConteudo := PadL(cConteudo, nTamanho)
			
			Case cAlign == "C" //CENTER (Conteudo Alinhado ao Centro)
				
				cConteudo := PadC(cConteudo, nTamanho)
		EndCase
		cLinhaRet += cTagIniLin + cConteudo + cTagFimLin + cPula

		//verifica capacidade para a descrição do item e caso não comporte, utiliza proxima linha para manter a integridade da descrição
		If !Empty(cDescrPro)
			cConteudo := Substr(cDescrPro,1,nQtdColuna)
			cDescrPro := Substr(cDescrPro,nQtdColuna+1,Len(cDescrPro))	 
			nTamanho  := nQtdColuna
		Else
			cConteudo := ""
		EndIf
	End
	
Next nInd

cLinhaRet += cCrLf

Return cLinhaRet

//----------------------------------------------------------------
/*/{Protheus.doc} LjPrtNccCB
Efetua a impressao da NCC com Código de Barras.

@author  Alberto Deviciente
@version P12.1.17
@since   12/12/2018

@param	 aPrintNCC, 	Array, 	Informacoes da NCC a ser impressa
@param	 lImpFiscal,	Lógico,	Indica se a impressao sera na impressora Fiscal (.T.) ou Nao Fiscal (.F.)

@return	 Numerico,		Retorna o codigo de retorno do comando de impressao.
/*/
//------------------------------------------------------------------
Function LjPrtNccCB(aPrintNCC,lImpFiscal)
Local nRet			:= -1
Local nX 			:= 0
Local cTxtCab 		:= ""
Local cTxtCodBar	:= ""
Local cTxtRodape 	:= ""

For nX:=1 To Len(aPrintNCC)
	cTxtCab		:= aPrintNCC[nX][1]
	cTxtCodBar 	:= aPrintNCC[nX][2]
	cTxtRodape 	:= aPrintNCC[nX][3]

	If !lImpFiscal //Impressora Nao Fiscal
		
		cTxtCab += CHR(10) + CHR(10)
		
		cTxtCodBar := cTxtCodBar + CHR(10) + "<code128>" + cTxtCodBar  + "</code128>"
		cTxtCodBar := "<ce>" + cTxtCodBar + "</ce>" //Centralizado
		cTxtCodBar += CHR(10) + CHR(10)

		cTxtRodape += CHR(10) + CHR(10)

		// Corta Papel
		cTxtRodape += "<gui></gui>"

		//Faz a impressao na impressora Nao Fiscal
		nRet := INFTexto( cTxtCab + cTxtCodBar + cTxtRodape, .T. )

	Else //Impressora Fiscal
		cTxtCab := cTxtCab + CHR(10) + CHR(10) + cTxtCodBar

		//Faz impressao de relatorio gerencial com codigo de barras na impressora Fiscal
		nRet := IfCodBar( nHdlEcf, cTxtCab, cTxtCodBar, cTxtRodape, 1 )

	EndIf
Next nX

Return nRet