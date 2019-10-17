#INCLUDE "PROTHEUS.CH"
#INCLUDE "LOJA701G.CH"                                                                                                                                                                                                                                              

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7GerPedVFE ºAutor³Vendas Clientes     º Data ³  10/09/14  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Gera Pre-Nota de Entrada e Pedido de Venda Para VFE - Venda º±± 
±±º          ³Fora do Estado - Minas Gerais								    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := LJGerPedVFE( ExpA1 ) 					              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Array com os pedidos	    		                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   
Function LJ7GerPedVFE(cTipo, aSL1, aSL2, cFilEnt, cFilRES, cFilLoc)
         
Local nI 		:= 0							//Contador
Local nJ 		:= 0							//Contador
Local nY		:= 0							//Contador
Local nPos		:= 0							//Posicao
Local nPrcVen	:= 0							//Preco de Venda
Local nPrcItem	:= 0							//Preco do Item
Local nPerDesc 	:= 0							//Percentual de Desconto
Local nValDesc 	:= 0							//Valor de Desconto
Local nPrUnit	:= 0							//Preco Unitario
Local cFilBkp	:= cFilAnt						//Bkp Filial
Local cFilPed	:= ""						 	//Filial Pedido
Local cNumSC5	:= CRIAVAR("C5_NUM",.F.)		//Numero do Pedido	- Inclusao
Local cMay		:= ""							//Verificar se nao esta utilizando a numeração
Local aCabPed	:= {}							//Cabeçalho Pedido
Local aLinhaPed	:= {}							//Item Pedido
Local aItensPed	:= {}							//Itens Pedido
Local lLiber 	:= .F.							//Compatibilizacao com o SIGAFAT
Local lTransf	:= .F.      					//Compatibilizacao com o SIGAFAT	
Local lLiberOk 	:= .T.							//Compatibilizacao com o SIGAFAT
Local lResidOk 	:= .T.							//Compatibilizacao com o SIGAFAT		
Local lFaturOk 	:= .F.							//Compatibilizacao com o SIGAFAT	
Local lTLVReg  	:= .F.							//Compatibilizacao com o SIGAFAT
Local cTesPed	:= ""                    		//Tes do Pedido de Venda                                                               
Local cPedido  	:= ""							//Recebe o codigo do pedido 
Local cMenNota  := ""							//Armazena o descricao do complemento da nota - rodape 
Local cCDLocEmp := cFilRES						//Backup da variavel cFilRes
Local cCliente 	:= ""							//Recebe o codigo do cliente do pedido
Local cLoja		:= ""							//Recebe o codigo da loja
Local cClient   := ""							//Cliente de entrega
Local cLojEnt	:= ""							//Loja do Cliente de entrega
Local cCF       := ""							//Classificacao fiscal do produto
Local cUFCli	:= ""							//UF do cliente
Local cArmPed	:= ""							//Armazem do Pedido de Venda
Local cFilLoja	:= ""							//Filial Loja da Venda
Local cFilCdLoc	:= ""							//Filial CD Local para rodape
Local cTpCarga 	:= If(SuperGetMV("MV_LJGCOMS", NIL, .F.),"1", "2")// Carga  1-Utiliza \ 2-Nao utiliza

//Informacoes do cliente
cCliente	:= aSL1[aScan(aSL1, {|x| Alltrim(Upper(x[1])) == "L1_CLIENTE"})][2] //Cliente da Venda                                
cLoja		:= aSL1[aScan(aSL1, {|x| Alltrim(Upper(x[1])) == "L1_LOJA"})][2]    //Loja do Cliente da Venda

//Informacoes do Cliente de Entrega
cClient	:= aSL2[1][Ascan(aSL2[1], {|x| AllTrim(x[1]) == "L2_CLIENT"})][2]  //Cliente de Entrega                            
cLojEnt	:= aSL2[1][Ascan(aSL2[1], {|x| AllTrim(x[1]) == "L2_CLILOJA"})][2] //Loja do Cliente de Entrega

//Se cliente de entrega nao informado, considera cliente da venda
If Empty(cClient) .Or. Empty(cLojEnt) 
	cClient := cCliente
	cLojEnt := cLoja
EndIf

//Informacoes do Pedido
cPedido	:= aSL2[1][Ascan(aSL2[1], {|x| AllTrim(x[1]) == "L2_NUM"})][2]

cUFCli	:= Posicione("SA1", 1, xFilial("SA1") + cClient + cLojEnt, "SA1->A1_ESTE")

If Empty(cUFCli)
	cUFCli := Posicione("SA1", 1, xFilial("SA1") + cClient + cLojEnt, "SA1->A1_EST")
EndIf
						
Do Case                
	Case cTipo == "1" .Or. cTipo == "2" //Pedido de "Simples Faturamento" ## "Pedido de Remessa de Entrega Futura"							
		cCDLocEmp 	:= xFilial("SC5") //Filial Loja da Venda		                          		
		//Para Filial do CD Local, primeiro busca campo prioritario
		cFilCdLoc := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cFilCdLoc)
			cFilCdLoc := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
		EndIf					
	Case cTipo == "3"		 					
		//Para Filial do CD Local, primeiro busca campo prioritario
		cCDLocEmp := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cCDLocEmp)
			cCDLocEmp := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local
		EndIf		                         			
   	Case cTipo == "4"//Transferencia simbolica     					
		//Para Filial do CD Local, primeiro busca campo prioritario
		cCDLocEmp := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cCDLocEmp)
			cCDLocEmp := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local
		EndIf
		//Para Loja da Venda, busca diretamente na tabela SLJ pois podem haver varias lojas no Estado
		cFilLoja := Lj7FilLoja(SC5->C5_ORCRES)
		SLJ->(dbSetOrder(3))		
		SLJ->(dbSeek(xFilial("SLJ") + cEmpAnt + cFilLoja))
		cCliente	:= SLJ->LJ_CLIENTE
		cLoja		:= SLJ->LJ_LOJCLI                           
		cClient		:= cCliente                            
		cLojEnt		:= cLoja
	Case cTipo == "5" //Pedido de Venda - Cenario 2	
		//Para Filial do CD Local, primeiro busca campo prioritario
		cCDLocEmp := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cCDLocEmp)	
			cCDLocEmp := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
		EndIf	                        		
EndCase 

SL2->(dbSetOrder(1))
//Posiciona no Pedido de Venda TRF - Tipo 0
If SL2->(dbSeek(cFilEnt + cPedido))	
	SC5->(dbSetOrder(1))
	If SC5->(dbSeek(cFilEnt + SL2->L2_PEDRES))									
		SA1->(dbSetOrder(1))
		SA1->(dbSeek(xFilial("SA1") + cCliente + cLoja))
		// Armazena Cab/SC5	
		aCabPed := {}				
		aAdd(aCabPed, {"C5_FILIAL"	, cCDLocEmp      	, Nil})
		aAdd(aCabPed, {"C5_NUM"		, ""				, Nil})
		aAdd(aCabPed, {"C5_TIPO"	, "N"				, Nil})
		aAdd(aCabPed, {"C5_CLIENTE"	, cCliente			, Nil})
		aAdd(aCabPed, {"C5_LOJACLI"	, cLoja				, Nil})
		aAdd(aCabPed, {"C5_CLIENT"	, cClient			, Nil})
		aAdd(aCabPed, {"C5_LOJAENT"	, cLojEnt			, Nil})		
		aAdd(aCabPed, {"C5_TIPOCLI"	, SA1->A1_TIPO		, Nil})
		aAdd(aCabPed, {"C5_EMISSAO"	, SC5->C5_EMISSAO	, Nil})
		aAdd(aCabPed, {"C5_VEND1"	, SC5->C5_VEND1		, Nil})
		aAdd(aCabPed, {"C5_CONDPAG"	, SC5->C5_CONDPAG	, Nil})
		aAdd(aCabPed, {"C5_ORCRES"	, SC5->C5_ORCRES	, Nil})		
		aAdd(aCabPed, {"C5_SEGURO"	, SC5->C5_SEGURO	, Nil})
		aAdd(aCabPed, {"C5_DESPESA"	, SC5->C5_DESPESA	, Nil})
		//Apenas Pedidos de Vendas para o Consumidor Final conservam valores de Frete e Desconto		
		If 	cTipo $ "1|2|5"		
			aAdd(aCabPed, {"C5_TRANSP"	, SC5->C5_TRANSP	, Nil})
			aAdd(aCabPed, {"C5_TPFRETE"	, SC5->C5_TPFRETE	, Nil})
			aAdd(aCabPed, {"C5_FRETE"	, SC5->C5_FRETE		, Nil})
			aAdd(aCabPed, {"C5_FRETAUT"	, SC5->C5_FRETAUT	, Nil})
			aAdd(aCabPed, {"C5_RECFAUT"	, SC5->C5_RECFAUT	, Nil})
			aAdd(aCabPed, {"C5_DESCONT"	, SC5->C5_DESCONT	, Nil})
			aAdd(aCabPed, {"C5_DESC1"	, SC5->C5_DESC1		, Nil})							
			aAdd(aCabPed, {"C5_DESC2"	, SC5->C5_DESC2		, Nil})
			aAdd(aCabPed, {"C5_DESC3"	, SC5->C5_DESC3		, Nil})
			aAdd(aCabPed, {"C5_DESC4"	, SC5->C5_DESC4		, Nil})
			aAdd(aCabPed, {"C5_DESCFI"	, SC5->C5_DESCFI	, Nil})
		Else			
			aAdd(aCabPed, {"C5_TRANSP"	, ""				, Nil})
			aAdd(aCabPed, {"C5_TPFRETE"	, SA1->A1_TPFRET	, Nil})
			aAdd(aCabPed, {"C5_FRETE"	, 0					, Nil})
			aAdd(aCabPed, {"C5_FRETAUT"	, 0					, Nil})
			aAdd(aCabPed, {"C5_RECFAUT"	, ""				, Nil})
			aAdd(aCabPed, {"C5_DESCONT"	, 0					, Nil})
			aAdd(aCabPed, {"C5_DESC1"	, 0					, Nil})							
			aAdd(aCabPed, {"C5_DESC2"	, 0					, Nil})
			aAdd(aCabPed, {"C5_DESC3"	, 0					, Nil})
			aAdd(aCabPed, {"C5_DESC4"	, 0					, Nil})
			aAdd(aCabPed, {"C5_DESCFI"	, 0					, Nil})
		EndIf						
		aAdd(aCabPed, {"C5_MOEDA"	, SC5->C5_MOEDA		, Nil})
		aAdd(aCabPed, {"C5_TIPLIB"	, SC5->C5_TIPLIB	, Nil})
		aAdd(aCabPed, {"C5_TPCARGA"	, cTpCarga			, Nil})
		aAdd(aCabPed, {"C5_GERAWMS"	, SC5->C5_GERAWMS	, Nil})
		aAdd(aCabPed, {"C5_MENPAD"	, SC5->C5_MENPAD	, Nil})
		aAdd(aCabPed, {"C5_TPCD"	, cTipo				, Nil})
		//Dados complementares no rodape
		cMenNota := ""
		If cTipo $ "2|3"   
			If cTipo == "2"			
				cFilAnt := cFilCdLoc //Filial Cd Local			
			EndIf						

			SM0->(dbSetOrder(1))
			SM0->(dbSeek(Substr(cEmpAnt, 1, 2) + cFilAnt)) 
			cMenNota := STR0001 + alltrim(SM0->M0_ENDENT) +; //"Endereco: "
						STR0002 + alltrim(SM0->M0_COMPENT)+; //", Complemento :"
						STR0003 + alltrim(SM0->M0_BAIRENT)+; //", Bairro :"
						STR0004 + alltrim(SM0->M0_CIDENT)+; //", Cidade :"
						STR0005 + alltrim(SM0->M0_ESTENT)+; //", Estado :"
						STR0006 + SM0->M0_CEPENT+; //", CEP :"
						STR0007 + SM0->M0_INSC +" , "+; //" ** Insc.Estadual: "
						STR0008 + alltrim(SM0->M0_NOMECOM) +" , "+; //" ** Razao Social: "
						STR0009 + SM0->M0_CGC+"  " //" ** CNPJ "			
			//Posiciona filial origem (Loja da Venda)
			cFilAnt := Lj7FilLoja(SC5->C5_ORCRES)
			SM0->(dbSeek(Substr(cEmpAnt, 1, 2) + cFilAnt))					
		EndIf
		aAdd(aCabPed, {"C5_MENNOTA", cMenNota, Nil})
		//Posiciona filial que sera gerado o Pedido de Venda
		cFilAnt := cCDLocEmp
		//Numeração Pedido				
		cNumSC5 := GetSxeNum("SC5","C5_NUM")							
		//Localiza a Filial
		If (cTipo == "1") .Or. (cTipo = "2") 
			cMay := "SC5" + ALLTRIM(xFilial("SC5")) + cNumSC5
			While !Eof() .AND. SC5->(DbSeek(xFilial("SC5") + cNumSC5) .OR. !MayIUseCode(cMay))
				cNumSC5 := Soma1(cNumSC5,Len(cNumSC5))
				cMay 	 := "SC5" + AllTrim(xFilial("SC5")) + cNumSC5
			EndDo
		Else
			//cFilAnt := cCDLocEmp //E esse comando que altera a Filial 				
			cMay := "SC5" + AllTrim(cCDLocEmp) + cNumSC5 			   	
			While !Eof() .AND. SC5->(dbSeek(cCDLocEmp + cNumSC5) .OR. !MayIUseCode(cMay))
				cNumSC5 := Soma1(cNumSC5, Len(cNumSC5))
				cMay 	 := "SC5" + AllTrim(cFilEnt) + cNumSC5
			EndDo	
		EndIf	

		If __lSX8
			ConfirmSX8()
		EndIf	

		//Troca numeracao
		nPos := aScan(aCabPed, {|x| Alltrim(Upper(x[1])) == "C5_NUM"})
		aCabPed[nPos][2] := cNumSC5
		//Grava Cabeçalho Pedido de Venda
	 	If Len(aCabPed) > 0              
			RecLock("SC5",.T.)
			For nJ := 1 To Len(aCabPed)
		 		SC5->&(aCabPed[nJ][1]) := aCabPed[nJ][2]
		   	Next nJ                                                   
		EndIf   	
		
		FkCommit() //Commit para integridade referencial do SC5									
		//Checando o parametro de acordo com o tipo de chamada
		Do Case
			Case  cTipo == "1" //Pedido de "Simples Faturamento", pedido emitido na mesma filial do estabelecimento que realizou a venda 
				cTesPed := SuperGetMv("MV_LJPEDSF",, "")                                                                                          
				If !Empty(cTesPed)
					If Substr(cTesPed, 1, 1) == "&"
		        		cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))
			        EndIf			    			      
			    EndIf
			Case  cTipo == "2" //"Remessa Entrega Futura"
				cTesPed := SuperGetMv("MV_LJPEDEF",, "")                                                                                          
				If !Empty(cTesPed)
					If Substr(cTesPed, 1, 1) == "&"
			        	cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))			    			    			     				   
			    	EndIf
			    EndIf    
			Case  cTipo == "3" //"Remessa por Conta e Ordem de Estabelecimento Showroom"
				cTesPed := SuperGetMv("MV_LJPEDRC",, "")                                                                                          
				If !Empty(cTesPed)
					If Substr(cTesPed, 1, 1) == "&"
			        	cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))
			   	    EndIf			   	
			   	EndIf    
			Case  cTipo == "4" //"Transferencia Simbolica"
				cTesPed := SuperGetMv("MV_LJPEDTS",, "")                                                                                          
				If !Empty(cTesPed)
					If Substr(cTesPed, 1, 1) == "&"
			        	cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))
			   	    EndIf
			  	EndIf
			 Case cTipo == "5" //"Cenario 2 - Transferencia" 
			 	cTesPed := SuperGetMv("MV_TESVEND",, "")                                                                                          
				If !Empty(cTesPed)
					If Substr(cTesPed, 1, 1) == "&"
			        	cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))
			   	    EndIf
			  	EndIf 	    
		EndCase			

		//Itens Pedido						
		SC6->(dbSetOrder(1))
		If SC6->(dbSeek(cFilEnt+SL2->L2_PEDRES))											
			While SC6->(!Eof()) .AND. SC6->C6_FILIAL == cFilEnt .AND. SC6->C6_NUM == SL2->L2_PEDRES																
				//Se Tes Nao informada, busca TES Inteligente
				If Empty(cTesPed)
					cTesPed := MaTESInt(2, "01", cCliente, cLoja, "C", SC6->C6_PRODUTO)										
				EndIf
				//Armazena Preco de Venda
				nPrcVen := SC6->C6_PRCVEN
				//Armazena Valor Total do Item
				nPrcItem := SC6->C6_VALOR
				//Armazena o Preco Unitario
				nPrUnit := SC6->C6_PRUNIT
				//Armazena Vaores de Descontos
				nPerDesc := SC6->C6_DESCONT
				nValDesc := SC6->C6_VALDESC	
				//Inicializa Armazem do produto
				cArmPed := SC6->C6_LOCAL				
				//Busca Armazem do produto
				If AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SB1"
					SB1->(dbSetOrder(1))
					If SB1->(dbSeek(xFilial("SB1") + SC6->C6_PRODUTO)) 
				   		cArmPed := SB1->B1_LOCPAD						
					EndIf
				ElseIf AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SBZ" 
					SBZ->(dbSetOrder(1))
					If SBZ->(dbSeek(xFilial("SBZ") + SC6->C6_PRODUTO))
				   		cArmPed := SBZ->BZ_LOCPAD
					EndIf										
				EndIf			
				//Tratamento para Desconto, Frete e Preco de Venda nos Pedidos de Transferencia
				If cTipo $ "0|4" 
					//Inicializa Preco de Venda Auxiliar
					nPrcVen := 0
					If AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "1" // Obtem preco - custo standard						
						nPrcVen := Posicione("SB1", 1, xFilial("SB1") + SC6->C6_PRODUTO, "B1_CUSTD")											
					ElseIf AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "2" //Obtem preco - ultimo preco de compra						
						nPrcVen := Posicione("SB1", 1, xFilial("SB1") + SC6->C6_PRODUTO, "B1_UPRC")											
					ElseIf AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "3" //Obtem preco - custo medio unitario do armazem
						nPrcVen := Posicione("SB2", 1, xFilial("SB2") + SC6->C6_PRODUTO + cArmPed, "B2_CM1")														
					EndIf
					//Senao encontrou nenhum valor assume 1
					If nPrcVen == 0
						nPrcVen := 1
					EndIf
					nPrcItem := nPrcVen * SC6->C6_QTDVEN
					nPrUnit  := nPrcVen
					//Pedido de Venda e Simples Faturamento, Transferencia Simbolica e Transferencia , nao devem constar Frete e Desconto	
					nPerDesc := 0
					nValDesc := 0																																																																																																																																											
				EndIf	
																																												
				SF4->(DBSetOrder(1))
				If SF4->(DbSeek(xFiliaL("SF4") + cTesPed))
					cCF := SF4->F4_CF
				EndIf								
														
				aLinhaPed := {} 
				//Troca Filial
				If (cTipo == "1") .Or. (cTipo = "2") .Or. (cTipo = "3")
					aAdd(aLinhaPed,{"C6_FILIAL", xFilial("SC6"), Nil})
				Else
					aAdd(aLinhaPed,{"C6_FILIAL", cCDLocEmp, Nil})			   	
				EndIf	
				aAdd(aLinhaPed, {"C6_NUM"		, cNumSC5						, Nil})
				aAdd(aLinhaPed, {"C6_ITEM"		, SC6->C6_ITEM					, Nil})
				aAdd(aLinhaPed, {"C6_PRODUTO"	, SC6->C6_PRODUTO				, Nil})
				aAdd(aLinhaPed, {"C6_DESCRI"	, SC6->C6_DESCRI				, Nil})
				aAdd(aLinhaPed, {"C6_UM"		, SC6->C6_UM					, Nil})
				aAdd(aLinhaPed, {"C6_QTDVEN"	, SC6->C6_QTDVEN				, Nil})		   
				aAdd(aLinhaPed, {"C6_QTDLIB"	, SC6->C6_QTDVEN				, Nil})						
				aAdd(aLinhaPed, {"C6_PRCVEN"	, nPrcVen						, Nil})
				aAdd(aLinhaPed, {"C6_VALOR"		, nPrcItem					 	, Nil})				
				aAdd(aLinhaPed, {"C6_DESCONT"	, nPerDesc					 	, Nil})
				aAdd(aLinhaPed, {"C6_VALDESC"	, nValDesc					 	, Nil})				
				aAdd(aLinhaPed, {"C6_TES"		, cTesPed						, Nil})
				aAdd(aLinhaPed, {"C6_CF"		, cCF							, Nil})
				aAdd(aLinhaPed, {"C6_LOCAL"		, cArmPed						, Nil}) 
				aAdd(aLinhaPed, {"C6_CLI"		, SC6->C6_CLI 					, Nil})
				aAdd(aLinhaPed, {"C6_LOJA"		, cFilLoc		 				, Nil})
				aAdd(aLinhaPed, {"C6_PRUNIT"	, nPrUnit						, Nil})
				aAdd(aLinhaPed, {"C6_TPOP"		, SC6->C6_TPOP					, Nil})
				aAdd(aLinhaPed, {"C6_LOTECTL"	, SC6->C6_LOTECTL				, Nil})
				aAdd(aLinhaPed, {"C6_ENTREG"	, SC6->C6_ENTREG				, Nil})
				aAdd(aLinhaPed, {"C6_CLASFIS"	, SC6->C6_CLASFIS				, Nil})
				aAdd(aLinhaPed, {"C6_QTDEMP"	, 0				 				, Nil})
				aAdd(aLinhaPed, {"C6_RESERVA"	, ""			 				, Nil})
				aAdd(aItensPed, aLinhaPed)
				SC6->( DbSkip() )					
			EndDo
			For nI := 1 To Len(aItensPed)
				RecLock("SC6",.T.)
				For nY := 1 to Len(aItensPed[nI])                 
					If SC6->(FieldPos(aItensPed[nI][nY][1]) > 0)
						SC6->(FieldPut(FieldPos(aItensPed[nI][nY][1]), aItensPed[nI][nY][2]))
					EndIf	
		 		Next nY
		 		SC6->(MsUnlock())		
			   	FkCommit() // Commit para integridade referencial do SC6  
   	        	RecLock("SC6",.F.)
   	        	MaAvalSC6("SC6", 1, "SC5", lLiber, lTransf, @lLiberOk, @lResidOk, @lFaturOk,,,,,, lTLVReg)
				SC6->(MsUnlock())	                             			   	        										   		   		
		   	Next nI 		   			   	  			
		EndIf
		MaAvalSC5("SC5", 1, lLiber, lTransf, @lLiberOk, @lResidOk, @lFaturOk,,,,,, .F.)
		SC5->(MsUnlock())				
	EndIf		
	
	//Ajusta o tipo do pedido de TRF - Tipo 0, Pedido de Transferencia no CD Matriz
	If cTipo $ "4|5" 			
		cFilAnt := cFilEnt //Altera filial
		SC5->(dbSetOrder(1))
		If SC5->(dbSeek(xFilial("SC5")+SL2->L2_PEDRES))
			RecLock("SC5",.F.)				            
			//Pedidos de Transferencia nao considera valores de Frete e Desconto
			SC5->C5_TRANSP	:= ""	
			SC5->C5_TPFRETE	:= ""	
			SC5->C5_FRETE	:= 0		
			SC5->C5_FRETAUT	:= 0		
			SC5->C5_RECFAUT	:= ""	
			SC5->C5_DESCONT	:= 0		
			SC5->C5_DESC1	:= 0									
			SC5->C5_DESC2	:= 0		
			SC5->C5_DESC3	:= 0		
			SC5->C5_DESC4	:= 0		
			SC5->C5_DESCFI	:= 0								
			SC5->C5_TPCD 	:= "0"				               
			SC5->(MsUnlock())

			//Itens Pedido						
			SC6->(dbSetOrder(1))						
			If SC6->(dbSeek(xFilial("SC6")+SC5->C5_NUM))											
				While SC6->(!Eof()) .AND. SC6->C6_FILIAL == SC5->C5_FILIAL .AND. SC6->C6_NUM == SC5->C5_NUM
					nPrcVen := 0
					If AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "1" // Obtem preco - custo standard						
						nPrcVen := Posicione("SB1", 1, xFilial("SB1") + SC6->C6_PRODUTO, "B1_CUSTD")											
					ElseIf AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "2" //Obtem preco - ultimo preco de compra						
						nPrcVen := Posicione("SB1", 1, xFilial("SB1") + SC6->C6_PRODUTO, "B1_UPRC")											
					ElseIf AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "3" //Obtem preco - custo medio unitario do armazem
						nPrcVen := Posicione("SB2", 1, xFilial("SB2") + SC6->C6_PRODUTO + SC6->C6_LOCAL, "B2_CM1")														
					EndIf
					//Senao encontrou nenhum valor assume 1
					If nPrcVen == 0
						nPrcVen := 1
					EndIf
					//Atualiza preco de venda do Pedido de transferencia
					SC6->(RecLock("SC6", .F.))
					SC6->C6_PRCVEN  := nPrcVen
					SC6->C6_VALOR   := nPrcVen * SC6->C6_QTDVEN
					SC6->C6_DESCONT := 0
					SC6->C6_VALDESC := 0
					SC6->C6_PRUNIT  := nPrcVen
					SC6->(MsUnLock("SC6"))
					
					//Atualiza Preco de Venda no SC9 
					SC9->(dbSetOrder(2)) //C9_FILIAL+C9_CLIENTE+C9_LOJA+C9_PEDIDO+C9_ITEM
		   			If SC9->(dbSeek(SC6->C6_FILIAL + SC6->C6_CLI + SC6->C6_LOJA + SC6->C6_NUM + SC6->C6_ITEM))
		   				RecLock("SC9",.F.)
   	        			SC9->C9_PRCVEN := SC6->C6_PRCVEN
						SC9->(MsUnlock())		
		   			EndIf
					SC6->(dbSkip())
				EndDo
			EndIf
		EndIf
	EndIf 		
EndIf
//Restaura filial original 
cFilAnt := cFilBkp	

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7GerPreNT  ºAutor³Vendas Clientes     º Data ³  18/09/14  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Gera Pre-Nota de Entrada e Pedido de Venda Para VFE - Venda º±± 
±±º          ³Fora do Estado - Minas Gerais								  	 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := LJGerPreNT( ExpA1 ) 				      	           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 -   		                                              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   
Function LJ7GerPreNT(aPedido)

Local cFilCDLocal	:= "" //armazena o codigo da Filial do CD Local      
Local aLinha	   	:= {}  // armazena o(s) iten(s) da Nota Fiscal de Entrada
Local cFilBkp	   	:= cFilAnt // armazena a filial anterior para restaurar o backup
Local cFilPed		:= ""  //Filial Pedido	
Local cFornecedor	:= ""  //armazena o fornecedor
Local cFornLJ    	:= ""  //Armazena a loja do fornecedor
Local cChave     	:= ""  //Armazena o codigo do pedido 
Local cOrcRes    	:= ""  //Armazena o codigo do orcamento
Local cTipo      	:= "1" //Armazena o tipo de chamada  
Local lLjF1Clas  	:= .F. //Identifica a rotina a ser utilizado para gerar a pre-nota do pedido. MATA140 e Mata103
Local cTesSF1		:= SuperGetMv("MV_LJENTVF",, "001") //Armazena a TES                     					
Local cCF		   	:= "" //Armazena a CF
Local cUFCli		:= ""
Local cItem			:= "0000" //Item do Documento
Local cArmDoc		:= "" //Armazem do Documento de Entrada
Local cCliEnt		:= "" //Cliente da Entrega
Local cLojEnt		:= "" //Loja do Cliente de Entrega
Local cNFiscal   	:= "" //Numero do Documento de Saida      

//Ajusta Tes caso nao seja informada
If Empty(cTesSF1)
	cTesSF1 := "001"
EndIf
 
Private aXCabec	  	:= {}  //Cabecalho da NF de Entrada  
Private aXItens	  	:= {}  //Itens das NF de Entrada       
Private lMSErroAuto	:= .F.	//VerIfica se ocorreu algum erro durante a Geracao do PV
		
SC5->(dbSetOrder(1))
	
If SC5->(dbSeek(xFilial("SC5") + aPedido[1][1])) .And. SC5->C5_TPCD $ "0|4" //TRF ou Transferencia Simbolica		 
	cChave  := SC5->C5_NUM 
	cOrcRes := SC5->C5_ORCRES	
	cCliEnt := SC5->C5_CLIENT
	cLojEnt := SC5->C5_LOJAENT
		
	//Se Cliente de Entrega vazio, assume Cliente da Venda
	If Empty(cCliEnt) .Or. Empty(cLojEnt)
		cCliEnt := SC5->C5_CLIENTE
		cLojEnt := SC5->C5_LOJACLI
	EndIf
		 								 
	If (SC5->C5_ORCRES == cOrcRes .And. SC5->C5_TPCD == "0")//Pedido de transferencia = reserva(Passo 7 da especificacao tanto para o Cenario 1 quanto o Cenario 2)    	
    	cFornecedor := LJ7InfEnt(cEmpAnt, SM0->M0_ESTCOB, "0")[4] //Fornecedor CD Central
		cFornLJ     := LJ7InfEnt(cEmpAnt, SM0->M0_ESTCOB, "0")[5] //Loja CD Central					            
		cTipo       := "1" //Pedido de transferencia
							
		cUFCli := Posicione("SA1", 1, xFilial("SA1") + cCliEnt + cLojEnt, "SA1->A1_ESTE") 
		
		If Empty(cUFCli)
			cUFCli := Posicione("SA1", 1, xFilial("SA1") + cCliEnt + cLojEnt, "SA1->A1_EST")
		EndIf
		
		//Para Filial do CD Local, primeiro busca campo prioritario
		cFilCDLocal := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cFilCDLocal)	
			cFilCDLocal := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
		EndIf
		
		lLjF1Clas := .F.			      	    		    																					
    ElseIf (SC5->C5_ORCRES == cOrcRes .And. SC5->C5_TPCD == "4")//Transferencia simbolica(Passo 11 da especificacao)
   		cUFCli := Posicione("SA1", 1, xFilial("SA1") + cCliEnt + cLojEnt, "SA1->A1_ESTE") 
    		
   		If Empty(cUFCli)
			cUFCli := Posicione("SA1", 1, xFilial("SA1") + cCliEnt + cLojEnt, "SA1->A1_EST")
		EndIf
    		      	       			       			
    	cFilCDLocal := Lj7FilLoja(SC5->C5_ORCRES) //Filial da loja da venda
    	
    	//Para Fornecedor do CD Local, primeiro busca campo prioritario
    	cFornecedor := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[4] //Fornecedor CD Local				
		
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cFornecedor)
			cFornecedor := LJ7InfEnt(cEmpAnt, cUFCli, "1")[4] //Fornecedor CD Local
		EndIf
		
		//Para Loja do Fornecedor do CD Local, primeiro busca campo prioritario	
		cFornLJ := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[5] //Loja Cd Local
		
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cFornLJ)				
			cFornLJ := LJ7InfEnt(cEmpAnt, cUFCli, "1")[5] //Loja Cd Local					
		EndIf
		
		cTipo := "2" 
				
		lLjF1Clas := AllTrim(SuperGetMV("MV_LJDENT",, "0")) <> "0"																							                   			    
    EndIf
				    		 
	If !Empty(cFornecedor) .And. !Empty(cFornLJ)						
		//Armazena Numero da Nota Fiscal
		SF1->(dbSetOrder(1))
		
		//Verifica se ja existe a Numeracao na SF1
		If !SF1->(dbSeek(cFilCDLocal + SF2->F2_DOC + SF2->F2_SERIE + cFornecedor + cFornLJ))
			cNFiscal := SF2->F2_DOC
		Else //Se ja existir o Numero, busca o proximo sequencial
			cNFiscal := MA461NumNf(.T., "", cNFiscal)
		EndIf
						
		//Posiciona na SC6
		SC6->(dbSetOrder(1))
	   	
	   	SC6->(dbSeek(SC5->C5_FILIAL + SC5->C5_NUM))
	   										
		aAdd(aXCabec,{"F1_FILIAL", cFilCDLocal, Nil})
						
		//Verifica se o Documento sera classificado
	  	If lLjF1Clas		  		
		   	aAdd(aXCabec,{"F1_TIPO"		, "N"				, Nil})
    	   	aAdd(aXCabec,{"F1_FORMUL"   , "N" 				, Nil})   
			aAdd(aXCabec,{"F1_DOC"		, cNFiscal			, Nil})
			aAdd(aXCabec,{"F1_SERIE"		, SF2->F2_SERIE	, Nil})
			aAdd(aXCabec,{"F1_EMISSAO"	, dDataBase		, Nil})
			aAdd(aXCabec,{"F1_FORNECE"	, cFornecedor   	, Nil})
			aAdd(aXCabec,{"F1_LOJA"		, cFornLJ   		, Nil})
			aAdd(aXCabec,{"F1_ESPECIE"	, SF2->F2_ESPECIE	, Nil})
			aAdd(aXCabec,{"F1_EST"	   	, Posicione("SA2",1, xFilial("SA2") + cFornecedor + cFornLJ, "A2_EST"), Nil})
			aAdd(aXCabec,{"F1_COND"		, SF2->F2_COND	, Nil})	
			aAdd(aXCabec,{"F1_FILPV"		, SC5->C5_FILIAL	, Nil})
			aAdd(aXCabec,{"F1_NUMPV"		, SC5->C5_NUM		, Nil})
		Else	            					
			aAdd(aXCabec,{"F1_DOC"		, cNFiscal			, Nil})
			aAdd(aXCabec,{"F1_SERIE"		, SF2->F2_SERIE	, Nil})				
			aAdd(aXCabec,{"F1_EMISSAO"	, dDataBase		, Nil})
			aAdd(aXCabec,{"F1_FORNECE"	, cFornecedor   	, Nil})
			aAdd(aXCabec,{"F1_LOJA"		, cFornLJ   		, Nil})			
			aAdd(aXCabec,{"F1_EST"	   	, Posicione("SA2",1, xFilial("SA2") + cFornecedor + cFornLJ, "A2_EST"), Nil})
			aAdd(aXCabec,{"F1_COND"		, SF2->F2_COND	, Nil})	
			aAdd(aXCabec,{"F1_FILPV"		, SC5->C5_FILIAL	, Nil})
			aAdd(aXCabec,{"F1_NUMPV"		, SC5->C5_NUM		, Nil})													
	 	EndIf
	 	
	 	//Armazena informacoes de Origem
	 	aAdd(aXCabec,{"F1_FILORIG"	, SF2->F2_FILIAL	, Nil})	
		aAdd(aXCabec,{"F1_SERORIG"	, SF2->F2_SERIE	, Nil})
		aAdd(aXCabec,{"F1_NFORIG"	, cNFiscal			, Nil})		 	 	 		 	
	EndIf
		
	//Monta Itens do Documento
	If Len(aXCabec) > 0							
		SD2->(dbSetOrder(3))				
					
		If SD2->(dbSeek(xFilial("SD2") + SF2->F2_DOC + SF2->F2_SERIE + SF2->F2_CLIENTE + SF2->F2_LOJA))		                                                                                                	
			While SD2->(!Eof()) .AND. SD2->D2_FILIAL == SF2->F2_FILIAL .And. SD2->D2_DOC == SF2->F2_DOC .And.; 
					SD2->D2_SERIE == SF2->F2_SERIE .And. SD2->D2_CLIENTE == SF2->F2_CLIENTE .And.; 
					SD2->D2_LOJA == SF2->F2_LOJA
																	    				 				
				cItem  := Soma1(cItem)
								
				aLinha := {}
	
				aAdd(aLinha,{"D1_FILIAL"		, cFilCDLocal 		, Nil})
				aAdd(aLinha,{"D1_DOC"		, cNFiscal				, Nil})
				aAdd(aLinha,{"D1_SERIE"		, SF2->F2_SERIE		, Nil})
			   	aAdd(aLinha,{"D1_FORNECE"	, cFornecedor  		, Nil})
				aAdd(aLinha,{"D1_LOJA"		, cFornLJ  			, Nil})				
				aAdd(aLinha,{"D1_ITEM"		, cItem 				, Nil})					
				aAdd(aLinha,{"D1_COD"		, SD2->D2_COD			, Nil})
				aAdd(aLinha,{"D1_UM"			, SD2->D2_UM			, Nil})		
				aAdd(aLinha,{"D1_QUANT"		, SD2->D2_QUANT		, Nil})
				aAdd(aLinha,{"D1_VUNIT"		, SD2->D2_PRCVEN		, Nil})
				aAdd(aLinha,{"D1_TOTAL"		, SD2->D2_TOTAL		, Nil})					
				aAdd(aLinha,{"D1_DESC"		, 0						, Nil})
				aAdd(aLinha,{"D1_VALFRE"		, 0						, Nil})
				aAdd(aLinha,{"D1_EMISSAO"	, dDataBase			, Nil})
				aAdd(aLinha,{"D1_FILORI"		, SF2->F2_FILIAL		, Nil})
				aAdd(aLinha,{"D1_NFORI"		, SF2->F2_DOC			, Nil})
				aAdd(aLinha,{"D1_SERIORI"	, SF2->F2_SERIE		, Nil})					
				aAdd(aLinha,{"D1_NUMPV"		, SD2->D2_PEDIDO		, Nil})
															
				//Inicializa Armazem do Produto
				cArmDoc := SD2->D2_LOCAL
				
				//Altera Filial para buscar informacoes
				cFilPed := cFilAnt
				cFilAnt := cFilCDLocal
				
				//Classificacao do Documento de Entrada
				If lLjF1Clas 										
					aAdd(aLinha,{"D1_TES", cTesSF1, Nil})
					
					SF4->(dbSetOrder(1))						
					
					If SF4->(DbSeek(xFiliaL("SF4") + cTesSF1))
						cCF := SF4->F4_CF
					Else
						cCF := "112"						
             		EndIf
                       
					aAdd(aLinha,{"D1_CF", cCF, Nil})																												
				EndIf
												
				//Busca Armazem do produto
				If AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SB1"
					SB1->(dbSetOrder(1))

					If SB1->(dbSeek(xFilial("SB1") + SC6->C6_PRODUTO)) 
				   		cArmDoc := SB1->B1_LOCPAD						
					EndIf
				ElseIf AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SBZ" 
					SBZ->(dbSetOrder(1))
					
					If SBZ->(dbSeek(xFilial("SBZ") + SC6->C6_PRODUTO))
				   		cArmDoc := SBZ->BZ_LOCPAD
					EndIf									
				EndIf 
				
				aAdd(aLinha, {"D1_LOCAL", cArmDoc, Nil})				
				
				//Restaura Filial
				cFilAnt := cFilPed 
					
				aAdd(aXItens, aLinha)
												
				SD2->(dbSkip())
			EndDo				
		EndIf
		
		//Efetua a inclusao do Documento de Entrada
		cFilAnt := cFilCDLocal //E esse comando que altera a Filial   
				
		If lLjF1Clas						
			//Gera Documento de Entrada classificado
			Mata103(aXCabec, aXItens, 3)
		Else			
			//Gera Documento de Entrada sem classificacao
			Mata140(aXCabec, aXItens, 3,, 0)			    
		EndIf	
				
		If lMsErroAuto      
			MostraErro()					 												
		EndIf 
				
		cFilAnt := cFilBkp							     	   		
	EndIf									 
EndIf

Return Nil	

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7DelPreNT  ºAutor³Vendas Clientes     º Data ³  09/10/14  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Valida se o tipo de nota e diferente de 4 para permitir a   º±± 
±±º          ³exclusao de uma pre-nota   								  		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := LJDelPreNT( ExpA1, ExpA2 )   	      	          		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Filial da SF1										  	º±±
±±º          ³ExpC2 - Codigo do PV que originou a pre-nota                º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ lRet														  		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Function LJ7DelPreNT(cFilPV, cNumPV)

Local lRet := .T.

SC5->(dbSetOrder(1))

While SC5->(!Eof()) 
	If (SC5->C5_FILIAL == cFilPV ).And. (SC5->C5_ORCRES == cNumPV) .And. (SC5->C5_TPCD == "4")//Transferencia simbolica
    	lRet := .F.
		 MsgStop(STR0010, STR0011) //"Estorne manualmente e em seguida cancele!" #"Atenção"
		Exit										
    EndIf
	SC5->(DbSkip())	  
EndDo

Return lRet	

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÚÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄ¿±±
±±³Funcao    ³LJ7DESCPED ³ Autor ³SIGALOJA              ³ Data ³09/10/14  ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄ´±±
±±³Descri‡…o ³Retorna a descricao do tipo de pedido do CD                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Sintaxe   ³LJDESCPED()                                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Parametros³cTipo                                                      	³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³Retorno   ³Descricao do tipo de pedido                                 ³±±
±±ÃÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´±±
±±³          ³                                                            ³±±
±±ÀÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/
Function LJ7DESCPED(cTipo)
Local cDesc := ""

Do Case
	Case cTipo == "1"
		cDesc := STR0012 //"1-Simples Fat."
	Case cTipo == "2"
		cDesc := STR0013 //"2-Rem.Ent.Fut"
	Case cTipo == "3"
		cDesc := STR0014 //"3-Conta e Ordem"
	Case cTipo == "4"
		cDesc := STR0015 //"4-Trans.Simbol"
	OtherWise
		cDesc := STR0016 //"0-TRF"	
EndCase

Return cDesc	

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7LgReVFE ºAutor³Vendas Clientes     º Data ³  07/10/14    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Verifica se Venda fora do Estado (VFE) e efetua os tratamen-º±± 
±±º          ³tos para Logistica Reversa.        							 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ LJLojRevVFE( cSF2Fil, cSF2Doc, cSF2Serie )      	        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cSF2Fil - Filial da NF de Saida.                            º±±
±±           ³cSF2Doc - Numero da NF de Saida.                            º±±
±±           ³cSF2Serie - Serie da NF de Saida.                           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Function LJ7LgReVFE(cSF2Fil, cSF2Doc, cSF2Serie)

Local aArea     	:= GetArea()
Local aAreaSC5  	:= SC5->(GetArea())
Local aAreaSC6  	:= SC6->(GetArea())
Local aAreaSA1  	:= SA1->(GetArea())
Local aAreaSC9		:= SC9->(GetArea())
Local cFilLoja		:= "" 	//Filial da Loja de Venda
Local cFilCDLoc		:= ""	//Filial do CD Local
Local cFilNcc		:= "" 	//Filial da NCC
Local cUFCli		:= ""	//UF do cliente
Local cClient		:= "" //Cliente de Entrega
Local cLojEnt		:= "" //Loja do Cliente de Entrega
Local cFilBkp		:= cFilAnt //Armazena a filial original
Local lCen1VFE 		:=  LjAnalisaLeg(69)[1] .And. SuperGetMv("MV_LJC1VFE", Nil, .F.) //Especifico para Minas Gerais = Cenario 1 - Loja da Venda	
Local lRefaz		:= .F. //Flag para controle da pergunta MsgNoYes
Local lRet			:= .T. //Flag para verificar se continua o proceso de Logistica Reversa
Local nRet			:= 0
Local aPergs 		:= {}
Local aRet 			:= {}
Local aSC5			:= {}
Local aSC6			:= {}
Local aPedAux		:= {}
Local lLjTroAut		:= SuperGetMv("MV_LJTRVFE", Nil, .T.) //Valida se Tipo da Troca VFE Automatica 
Local cAliasTmp		:= GetNextAlias() 
Local lRetPerg		:= .T.
Local lLj7104		:= ExistBlock("LJ7104")

SC5->(dbSetOrder(1)) //C5_FILIAL+C5_NUM
SC6->(dbSetOrder(4)) //C6_FILIAL+C6_NOTA+C6_SERIE
SC9->(dbSetOrder(6)) //C9_FILIAL+C9_SERIENF+C9_NFISCAL+C9_CARGA+C9_SEQCAR
SA1->(dbSetOrder(1)) //A1_FILIAL+A1_COD+A1_LOJA

//Verifica se a Devolucao Original foi gravada na Base de Dados
//Condicional para a query		
cWhere := "% "
cWhere += " D1_FILIAL = " + "'" + xFilial("SD1") + "'"
cWhere += " AND D1_NFORI = " + "'" + cSF2Doc + "'"
cWhere += " AND D1_SERIORI = " + "'" + cSF2Serie + "'"
cWhere += " AND SD1.D_E_L_E_T_ = '' "			
cWhere += " %"              											
                                          
//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		D1_FILIAL, D1_DOC, D1_SERIE
	FROM %table:SD1% SD1							
		WHERE %exp:cWhere%
		GROUP BY D1_FILIAL, D1_DOC, D1_SERIE   			
EndSql			

//Posiciona no inicio do arquivo temporario
(cAliasTmp)->(dbGoTop())

//Posiciona na filial que gerou a NF de Saida
cFilAnt := cSF2Fil

//Inicia o processo de Logistica Reversa
If (cAliasTmp)->(!EOF())		
	//Posiciona no Pedido de Venda que gerou a NF de Saida	
	If SC9->(dbSeek(xFilial("SC9") + cSF2Serie + cSF2Doc))	
		//Verifica se NF de Saida foi VFE - campo C5_TPCD 2,3 ou 5		
		If SC5->(dbSeek(SC9->C9_FILIAL + SC9->C9_PEDIDO)) .And. SC5->C5_TPCD $ "2|3|5" //!Empty(SC5->C5_TPCD)						    		   		   							
			//Carrega Tipos de Retorno
			aAdd(aPergs, {3, STR0017, 1, {STR0018, STR0019, STR0020}, 50, ".T.", .T.}) //"Selecione o tipo de retorno" //#"Devolução" //##"Troca" //###"Reentrega"	
			
			If lLj7104
				aRet := ExecBlock("LJ7104",.F.,.F.)				
			Else
				lRetPerg := ParamBox(aPergs, STR0021, @aRet) //"Logística Reversa"
			Endif
			
			//Seleciona tipo de processo
			If lRetPerg												      			      			   		     						     			   						
				lRefaz := .F. //Flag para controle da pergunta MsgNoYes
				
				//Posiciona cliente do Pedido de Venda
				cCliEnt := SC5->C5_CLIENT
				cLojEnt := SC5->C5_LOJAENT
		
				//Se Cliente de Entrega vazio, assume Cliente da Venda
				If Empty(cCliEnt) .Or. Empty(cLojEnt) 
					cCliEnt := SC5->C5_CLIENTE
					cLojEnt := SC5->C5_LOJACLI
				EndIf
				
				SA1->(dbSeek(xFilial("SA1") + cCliEnt + cLojEnt))
				cUFCli := IIF(!Empty(SA1->A1_ESTE), SA1->A1_ESTE, SA1->A1_EST) 
												
				//Se a Loja da Venda Cenario 1, verifica se cliente tambem esta no Cenario 1
				If lCen1VFE
					//Verifica cenario de venda VFE para o cliente
					lCen1VFE := LjAnalisaLeg(69, cUFCli)[1] .And. SuperGetMv("MV_LJC1VFE", Nil, .F.) //Especifico para Minas Gerais = Cenario 1 - Cliente
				EndIf
																																
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Efetua Retornos³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ					 	
				If lCen1VFE //Cenario 1 - Venda no Estado de MG																																																					
					//Atualiza informacoes do Pedido Original no Documento de Entrada inicial
					SF1->(RecLock("SF1", .F.))
					SF1->F1_COND  := SC5->C5_CONDPAG						
					SF1->F1_FILPV := SC5->C5_FILIAL
					SF1->F1_NUMPV := SC5->C5_NUM
					SF1->(MsUnlock())
						
					If aRet[1] == 3 //Reentrega
						//Remessa por conta e ordem de Estabelecimento Showroom														  
						//Retorna NF de Remessa Entrega Futura
						LjMsgRun(STR0024, STR0023,; //"Retorno NF de Remessa Entr. Futura..." #//"Aguarde..."
									{|| LJ7PNtRev("2", SC5->C5_ORCRES, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC,; 
														(cAliasTmp)->D1_SERIE, cUFCli, SC5->C5_FILIAL, @lRet)})	
					Else //Troca e Devolucao																				
						If SC5->C5_TPCD == "2" //Remessa Entrega Futura							 							 					 					 
							//Retorna NF de Remessa por Conta e Ordem de Estabelecimento Showroom 							
							LjMsgRun(STR0022, STR0023,; //"Retorno NF de Remessa C. e Ord. de Estab. Showroom..." #//"Aguarde..."
										{|| LJ7PNtRev("3", SC5->C5_ORCRES, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC,; 
															(cAliasTmp)->D1_SERIE, cUFCli, SC5->C5_FILIAL, @lRet)}) 																										
						Else //Remessa por conta e ordem de Estabelecimento Showroom														  
							//Retorna NF de Remessa Entrega Futura
							LjMsgRun(STR0024, STR0023,; //"Retorno NF de Remessa Entr. Futura..." #//"Aguarde..."
										{|| LJ7PNtRev("2", SC5->C5_ORCRES, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC,; 
															(cAliasTmp)->D1_SERIE, cUFCli, SC5->C5_FILIAL, @lRet)})										
						EndIf
												
						If lRet //Valida se contina o processo
							//Retorna NF de Transferencia Simbolica
							LjMsgRun(STR0025, STR0023,; //"Retorno NF de Transf. Simbólica..." #//"Aguarde..."
											{|| LJ7PNtRev("4", SC5->C5_ORCRES, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC,; 
																(cAliasTmp)->D1_SERIE, cUFCli, SC5->C5_FILIAL, @lRet)})
							
							If lRet
								//Retorna NF de Entrada da Transferencia Simbolica
								LjMsgRun(STR0048, STR0023,; //"Retorno da NF de Entrada Transf. Simbólica"..." #//"Aguarde..."
												{|| LJ7NfSRev("4", SC5->C5_ORCRES, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC,; 
																	(cAliasTmp)->D1_SERIE, cUFCli, @lRet)})
							Else
								MsgAlert(STR0059) //"Atenção! O processo de Logística Reversa não foi efetuado."
							EndIf
						Else
							MsgAlert(STR0059) //"Atenção! O processo de Logística Reversa não foi efetuado."	
						EndIf
					EndIf					
				Else						
					//Atualiza informacoes do Pedido Original no Documento de Entrada inicial
					SF1->(RecLock("SF1", .F.))
					SF1->F1_COND 	:= SC5->C5_CONDPAG						
					SF1->F1_FILPV := SC5->C5_FILIAL
					SF1->F1_NUMPV := SC5->C5_NUM
					SF1->(MsUnlock())									
				EndIf															
							
				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Refaz Pedidos de Vendas³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				If lRet															
					If aRet[1] == 2 //Troca 																																																																															
						//Verifica se Tipo da Troca Automatica ou Manual
						If lLjTroAut //Automatica
							//Efetua a carga das informacoes para geracao dos Pedidos de Vendas					
							Lj7CargPV(aSC5, aSC6, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC, (cAliasTmp)->D1_SERIE,;
													SC5->C5_FILIAL, SC5->C5_NUM, lCen1VFE, "A") 	
						
							//Ponto de Entrada para manipulacao do Pedido de Venda Remessa Entrega Futura 
							If ExistBlock("LJ7097")																						
								aPedAux := ExecBlock("LJ7097",.F., .F., {aSC5, aSC6} )							
								
								If ValType(aPedAux) == "A" 
									aSC5 := aClone(aPedAux[1])	
									aSC6 := aClone(aPedAux[2])	
								EndIf																															
							EndIf
						
							//Cenario 1 - Venda no Estado de MG
							If lCen1VFE		
								//Refaz Pedido Remessa Entrega Futura
								LjMsgRun(STR0034, STR0023,; //"Refazendo Pedido Remessa Entr. Futura..." #//"Aguarde..."
											{|| LJ7GerPVRev("2", SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)})
							
								If lRet
									//Refaz Pedido Remessa por conta e ordem de Estabelecimento Showroom
									LjMsgRun(STR0035, STR0023,; //"Refazendo Pedido Remessa C. e Ord. de Estab. Showroom..." #//"Aguarde..."
												{|| LJ7GerPVRev("3", SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)}) 
						
									If lRet
										//Refaz Pedido Transferencia Simbolica
										LjMsgRun(STR0036, STR0023,; //"Refazendo Pedido Transf. Simbolica..." #//"Aguarde..."
													{|| LJ7GerPVRev("4" ,SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)})
									Else
										MsgAlert(STR0059) //"Atenção! O processo de Logística Reversa não foi efetuado."
									EndIf
								Else
									MsgAlert(STR0059) //"Atenção! O processo de Logística Reversa não foi efetuado."
								EndIf 							
							Else
								//Refaz Pedido de Venda
								LjMsgRun(STR0037, STR0023,; //"Refazendo Pedido de Venda..." #//"Aguarde..."
											{|| LJ7GerPVRev("5" ,SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)})
							EndIf																																										
						Else //Manual																																 																			
							nRet := Lj7PVManu(aSC5, aSC6, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC, (cAliasTmp)->D1_SERIE, SC5->C5_ORCRES, cUFCli,;
													SC5->C5_FILIAL, SC5->C5_NUM, SC5->C5_TPCD)
							
							lRet := nRet > 0 //Alimenta flag de validacao
												
							//Se usuario confirmou a geracao manual do Pedido de Venda, continua processo
							If lRet
								SA1->(dbSetOrder(1))
																				
								SA1->(dbSeek(xFilial("SA1") + SC5->C5_CLIENT + SC5->C5_LOJAENT))
								cUFCli := IIF(!Empty(SA1->A1_ESTE), SA1->A1_ESTE, SA1->A1_EST) 
																					
								//Se a Loja da Venda Cenario 1, verifica se cliente tambem Cenario 1
								If lCen1VFE
									//Verifica cenario de venda VFE para o cliente
									lCen1VFE := LjAnalisaLeg(69, cUFCli)[1] .And. SuperGetMv("MV_LJC1VFE", Nil, .F.) //Especifico para Minas Gerais = Cenario 1 - Cliente
								EndIf
							
								//Cenario 1 - Venda no Estado de MG							 
								If lCen1VFE 
									//Refaz Pedido Remessa por conta e ordem de Estabelecimento Showroom
									LjMsgRun(STR0035, STR0023,; //"Refazendo Pedido Remessa C. e Ord. de Estab. Showroom..." #//"Aguarde..."
												{|| LJ7GerPVRev("3", SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)}) 
								
									If lRet
										//Refaz Pedido Transferencia Simbolica
										LjMsgRun(STR0036, STR0023,; //"Refazendo Pedido Transf. Simbolica..." #//"Aguarde..."
													{|| LJ7GerPVRev("4" ,SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)}) 
									Else
										MsgAlert(STR0059) //"Atenção! O processo de Logística Reversa não foi efetuado."
									EndIf	
								EndIf
							
								//Para geracao manual e Cenario 2, pedido aberto em tela ja equivale ao Pedido de Venda do Cliente
																							
							Else //Se usuario cancelou a tela de Pedido de Vendas, apenas informa							
								MsgAlert(STR0038) //"Atenção! Os Pedidos de Vendas do processo de Logística Reversa não foram gerados."
							EndIf		 														
						EndIf																																																						
					ElseIf aRet[1] == 3 //Reentrega
						//Efetua a carga das informacoes para geracao dos Pedidos de Vendas					
						Lj7CargPV(aSC5, aSC6, (cAliasTmp)->D1_FILIAL, (cAliasTmp)->D1_DOC, (cAliasTmp)->D1_SERIE,; 
												SC5->C5_FILIAL, SC5->C5_NUM, lCen1VFE, "A")						
						
						//Cenario 1 - Venda no Estado de MG
						If lCen1VFE 												
							//Refaz Pedido Remessa por conta e ordem de Estabelecimento Showroom						
							LjMsgRun(STR0035, STR0023,; //"Refazendo Pedido Remessa C. e Ord. de Estab. Showroom..." #//"Aguarde..."						
										{|| LJ7GerPVRev("3", SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)}) 																					
						Else
							//Refaz Pedido de Venda
							LjMsgRun(STR0037, STR0023,; //"Refazendo Pedido de Venda..." #//"Aguarde..."
										{|| LJ7GerPVRev("5" ,SC5->C5_ORCRES, aSC5, aSC6, cUFCli, @lRet)})
						EndIf						
					EndIf 
				
					//Ponto de Entrada na finalizacao do processo
					If lRet
						If ExistBlock("LJ7100")
							ExecBlock("LJ7100", .F., .F., {aRet[1]})
						EndIf					
					EndIf
				EndIf								 											
			Else
				If MsgNoYes(STR0058) //#"Se esta operação for cancelada, não será realizada a Logística Reversa, confirma o cancelamento?"
					lRefaz := .F.	//Nao refaz as perguntas de Logistica Reversa																	
				Else
					lRefaz := .T. //Refaz as perguntas de Logistica Reversa					
				EndIf
			EndIf																														
		Else
			//Exclui Pedidos de Vendas VFE
			LJ7ExcPed(SC5->C5_ORCRES)
		EndIf				
	EndIf
EndIf

//Fecha Alias temporario
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf

//Restaura Filial original
cFilAnt := cFilBkp

//Restaura a entrada da rotina                                    
RestArea(aAreaSC5)
RestArea(aAreaSC6)
RestArea(aAreaSC9)
RestArea(aAreaSA1)
RestArea(aArea)

//Tratamento para situacao onde o ParamBox foi cancelado, porem usuario
//Nao confirmou o cancelamento da Logistica reversa, chama a rotina
//novamente
If lRefaz
	//Chama novamente a tela de Logística reversa
	LJ7LgReVFE(cSF2Fil, cSF2Doc, cSF2Serie)
EndIf	

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7InfEnt ºAutor³Vendas Clientes     º Data ³  09/10/14     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Busca informacoes sobre a entidade para a qual sera gerada aº±± 
±±º          ³Logistica Reversa.                 							 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ LJCadEntid( cEmpAtu, cUFAtu, cTipo )   		      	        º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cEmpAtu - Empresa atual - Logada.                           º±±
±±           ³cUFAtu - Estado da Filial atual - Logada.                   º±±
±±           ³cTipo - Tipo da Entidade para geracao da Logistica Reversa. º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ aRet - Array com informacoes da Entidade.                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Function LJ7InfEnt(cEmpAtu, cUFAtu, cTipo, lCdPrior)

Local aArea     	:= GetArea()
Local aAreaSLJ  	:= SLJ->(GetArea())
Local aRet			:= {"", "", "", "", "", ""}

Default lCdPrior := .F.

SLJ->(dbSetOrder(3)) //LJ_FILIAL+LJ_RPCEMP+LJ_RPCFIL

//Busca Filial da Entidade solicitada
If SLJ->(dbSeek(xFilial("SLJ") + cEmpAtu))
	While SLJ->(!EOF()) .And. SLJ->(LJ_FILIAL + LJ_RPCEMP) == xFilial("SLJ") + cEmpAtu 
		If SLJ->LJ_ESTADO == cUFAtu .And. SLJ->LJ_TPCD == cTipo 						
	 		aRet[1] := SLJ->LJ_RPCFIL
	 		aRet[2] := SLJ->LJ_CLIENTE
	 		aRet[3] := SLJ->LJ_LOJCLI
	 		aRet[4] := SLJ->LJ_FORNEC
	 		aRet[5] := SLJ->LJ_FORNLJ
	 		aRet[6] := SLJ->LJ_CDLOCAL	 		
	 			 			 			 		
	 		Exit
	 	EndIf
	 
	 	SLJ->(dbSkip())
	EndDo
	
	//Se informado posiciona, localiza CD Local prioritario
	If lCdPrior
		If !Empty(aRet[6])
			SLJ->(dbSetOrder(1)) //LJ_FILIAL+LJ_CODIGO
			
			If SLJ->(dbSeek(xFilial("SLJ") + aRet[6])) .And. SLJ->LJ_ESTADO == cUFAtu 
				aRet[1] := SLJ->LJ_RPCFIL
			 	aRet[2] := SLJ->LJ_CLIENTE
			 	aRet[3] := SLJ->LJ_LOJCLI
			 	aRet[4] := SLJ->LJ_FORNEC
			 	aRet[5] := SLJ->LJ_FORNLJ
			 EndIf
		Else
			aRet[1] := ""
			aRet[2] := ""
			aRet[3] := ""
			aRet[4] := ""
			aRet[5] := ""
		EndIf
	EndIf
EndIf

//Restaura a entrada da rotina                                    
RestArea(aAreaSLJ)
RestArea(aArea)

Return aRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7PNtRev ºAutor³Vendas Clientes     º Data ³  09/10/14     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua a geracao dos documentos de Logistica Reversa - NF  º±± 
±±º          ³ de Entrada que sera contra-partida da NF de Saida Original.º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ LJ7PNtRev( cTipoEnti, cOrcRes, cSF1Fil, cSF1Doc,;         º±±
±±           ³             	cSF1Serie )                      				 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cTipoEnti - Tipo da Entidade do Pedido. Contrapartida       º±±
±±           ³cOrcRes - Numero de Orcamento gerado pelo SIGALOJA.         º±±
±±           ³cSF1Fil - Filial da NF de Entrada Atual.                    º±±
±±           ³cSF1Doc - Numero da NF de Entrada Atual.                    º±±
±±           ³cSF1Serie - Serie da NF de Entrada Atual.                   º±±
±±           ³cUFCli - Estado do cliente da venda.  		                  º±±
±±           ³cFilPed - Filial do Pedido de Vendas original.              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Static Function LJ7PNtRev(cTipoEnti, cOrcRes, cSF1Fil, cSF1Doc,;
								 cSF1Serie, cUFCli, cFilPed, lRet)

Local aArea     	:= GetArea()
Local aAreaSF4  	:= SF4->(GetArea())
Local aAreaSF1  	:= SF1->(GetArea())
Local aAreaSD1  	:= SD1->(GetArea())
Local aAreaSB1  	:= SB1->(GetArea())
Local aAreaSBZ  	:= SBZ->(GetArea())
Local cNFiscal		:= "" //Numero do Documento de Entrada
Local cWhere		:= ""
Local cFilDoc		:= ""
Local cTesSF1		:= ""
Local cCfop			:= ""
Local cArmDoc		:= "" //Armazem do Produto
Local cFilBkp 		:= cFilAnt //Armazena filial original
Local cAliasTmp		:= GetNextAlias()
Local aCabec 		:= {}
Local aItens 		:= {}
Local aLinha 		:= {}
Local cSerNf		:= SuperGetMv("MV_LJSERVF", Nil, "1") //Serie da NF VFE  
     
Private lMsErroAuto := .F.

//Armazena Filial
If cTipoEnti == "2" //Remessa Entrega Futura
	cFilDoc  := cFilPed//Filial da Loja de Venda
Else //Remessa por Conta e Ordem de Estabelecimento Showroom, Transf. Simbolica ou NF de Venda no Cenario 2  
	//Para Filial do CD Local, primeiro busca campo prioritario
	cFilDoc := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		
	//Se nao encontrar prioritario, busca CD Local do Estado(UF)
	If Empty(cFilDoc)	
		cFilDoc := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
	EndIf				
EndIf 

SF4->(dbSetOrder(1)) //F4_FILIAL+F4_CODIGO
SF1->(dbSetOrder(1)) //F1_FILIAL+F1_DOC+F1_SERIE+F1_FORNECE+F1_LOJA+F1_TIPO
SD1->(dbSetOrder(1)) //D1_FILIAL+D1_DOC+D1_SERIE+D1_FORNECE+D1_LOJA+D1_COD+D1_ITEM

//Condicional para a query		 				
cWhere := "% "
cWhere += " C5_FILIAL = " + "'" + xFilial("SC5") + "'"
cWhere += " AND C5_ORCRES = " + "'" + cOrcRes + "'"
cWhere += " AND C5_TPCD = " + "'" + cTipoEnti + "'"
cWhere += " AND SC5.D_E_L_E_T_ = '' "   		   		
cWhere += " AND SC6.D_E_L_E_T_ = '' "		
cWhere += " %"
                                          
//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		C5_FILIAL, C5_NUM, C5_CLIENTE, C5_LOJACLI, C5_SERIE, C5_NOTA, 
		C5_TPCD, C5_CONDPAG, C6_TES, C6_NOTA, C6_SERIE, C6_NUM
	FROM %table:SC5% SC5						
	INNER JOIN %table:SC6% SC6
		ON C5_FILIAL = C6_FILIAL AND C5_NUM = C6_NUM  
		WHERE %exp:cWhere% 
   		GROUP BY C5_FILIAL, C5_NUM, C5_CLIENTE, C5_LOJACLI, C5_SERIE, C5_NOTA,
   			C5_TPCD, C5_CONDPAG, C6_TES, C6_NOTA, C6_SERIE, C6_NUM
EndSql			

//Posiciona no inicio do arquivo temporario		
(cAliasTmp)->(dbGoTop())

//Altera filial
cFilAnt := cFilDoc
	
//Armazena informacoes da Venda
While (cAliasTmp)->(!EOF())
	//Verifica se o Pedido foi devolvido
	If !LojC090Dev((cAliasTmp)->C5_FILIAL, (cAliasTmp)->C5_NUM, (cAliasTmp)->C5_NOTA, (cAliasTmp)->C5_SERIE, (cAliasTmp)->C5_TPCD)					
		//Gera NF de Devolucao
		If SF4->(dbSeek(xFilial("SF4") + (cAliasTmp)->C6_TES)) 
			cTesSF1 := SF4->F4_TESDV
		
			//Posiciona na TES de Devolucao para pegar CFOP
			If SF4->(dbSeek(xFilial("SF4") + cTesSF1))
				cCfop := SF4->F4_CF
			EndIf
														
			//Altera filial para Documento de Devolucao
			cFilAnt := cSF1Fil
			
			//Verifica se ja existe a Numeracao na SF1
			If !SF1->(dbSeek(xFilial("SF1") + cSF1Doc + cSerNf))
				cNFiscal := cSF1Doc
			Else //Se ja existir o Numero, busca o proximo sequencial
				cNFiscal := MA461NumNf(.T., "", cNFiscal)
			EndIf
		
			//Posiciona na NF de Entrada Atual
			If SF1->(dbSeek(xFilial("SF1") + cSF1Doc + cSF1Serie))													
				//Adiciona Cabecalho da NF de Devolucao
				aAdd(aCabec, {"F1_TIPO"   	, "D"})		
				aAdd(aCabec, {"F1_FORMUL" 	, SF1->F1_FORMUL})		
				aAdd(aCabec, {"F1_DOC"    	, cNFiscal})		
				aAdd(aCabec, {"F1_SERIE"  	, cSerNf})		
				aAdd(aCabec, {"F1_EMISSAO"	, dDataBase})		
				aAdd(aCabec, {"F1_FORNECE"	, (cAliasTmp)->C5_CLIENTE})		
				aAdd(aCabec, {"F1_LOJA"   	, (cAliasTmp)->C5_LOJACLI})		
				aAdd(aCabec, {"F1_ESPECIE"	, SF1->F1_ESPECIE})		
				aAdd(aCabec, {"F1_COND"		, (cAliasTmp)->C5_CONDPAG})
				aAdd(aCabec, {"F1_FILORIG"  , (cAliasTmp)->C5_FILIAL})
				aAdd(aCabec, {"F1_SERORIG"  , (cAliasTmp)->C5_SERIE})				
				aAdd(aCabec, {"F1_NFORIG"	, (cAliasTmp)->C5_NOTA})		
				aAdd(aCabec, {"F1_FILPV"   	, (cAliasTmp)->C5_FILIAL})				
				aAdd(aCabec, {"F1_NUMPV"		, (cAliasTmp)->C5_NUM})						
			
				If SD1->(dbSeek(SF1->(F1_FILIAL + F1_DOC + F1_SERIE)))
					While SD1->(!EOF()) .And. SD1->(D1_FILIAL + D1_DOC + D1_SERIE) == SF1->(F1_FILIAL + F1_DOC + F1_SERIE)			
						aLinha := {}			
					
						//Adiciona Itens da NF de Devolucao
						aAdd(aLinha, {"D1_DOC"  		, cNFiscal					, Nil})
						aAdd(aLinha, {"D1_SERIE"  	, cSerNf					, Nil})
						aAdd(aLinha, {"D1_COD"  		, SD1->D1_COD				, Nil})			
						aAdd(aLinha, {"D1_QUANT"		, SD1->D1_QUANT			, Nil})			
						aAdd(aLinha, {"D1_VUNIT"		, SD1->D1_VUNIT			, Nil})			
						aAdd(aLinha, {"D1_TOTAL"		, SD1->D1_TOTAL			, Nil})			
						aAdd(aLinha, {"D1_TES"		, cTesSF1					, Nil})
						aAdd(aLinha, {"D1_CF"		, cCfop					, Nil})			
						aAdd(aLinha, {"D1_FILORI"	, (cAliasTmp)->C5_FILIAL	, Nil})
						aAdd(aLinha, {"D1_NFORI"		, (cAliasTmp)->C6_NOTA	, Nil})
						aAdd(aLinha, {"D1_SERIORI"	, (cAliasTmp)->C6_SERIE	, Nil})
						aAdd(aLinha, {"D1_NUMPV"		, (cAliasTmp)->C6_NUM	, Nil})						
						
						//Inicializa Armazem do Produto
						cArmDoc := SD1->D1_LOCAL
						
						//Busca Armazem do produto
						If AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SB1"
							SB1->(dbSetOrder(1))
		
							If SB1->(dbSeek(xFilial("SB1") + SD1->D1_COD)) 
						   		cArmDoc := SB1->B1_LOCPAD						
							EndIf
						ElseIf AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SBZ" 
							SBZ->(dbSetOrder(1))
							
							If SBZ->(dbSeek(xFilial("SBZ") + SD1->D1_COD))
						   		cArmDoc := SBZ->BZ_LOCPAD
							EndIf									
						EndIf 
				
						aAdd(aLinha, {"D1_LOCAL", cArmDoc, Nil})
						
						aAdd(aItens, aLinha)		
					
						SD1->(dbSkip())
					EndDo
				EndIf						
				
				//Retorna para filial do Documento de Entrada
				cFilAnt := cFilDoc
					
				//Inclusao da NF de Devolucao                                                      		
				MSExecAuto({|x,y,z| Mata103(x,y,z)}, aCabec, aItens, 3)					
				
				If lMsErroAuto							
					MostraErro()
					DisarmTransaction()
					lRet := .F.		
				EndIf						
			EndIf
		Else
			MsgAlert(STR0039 + (cAliasTmp)->C6_TES + STR0040 + xFilial("SF4") + STR0041 +; //"Atenção! TES: " #//" não cadastrada na filial: " ##//" ou não cadastrado campo TES de Devolução - F4_TESDV, "
						STR0042 + (cAliasTmp)->C5_NUM + STR0043) //"Geração da Nota de Devolução para o Pedido de Venda original: " #//" não efetuada."
						
			lRet := .F.	
		EndIf
	EndIf
	
	(cAliasTmp)->(dbSkip())
EndDo	

//Fecha Alias temporario
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf

//Restaura filial
cFilAnt := cFilBkp

//Restaura a entrada da rotina                                    
RestArea(aAreaSF4)
RestArea(aAreaSF1)
RestArea(aAreaSD1)
RestArea(aAreaSB1)
RestArea(aAreaSBZ)
RestArea(aArea)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7NfSRev ºAutor³Vendas Clientes     º Data ³  09/10/14     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua a geracao da Devolucao do Pedido de Transferencia.  º±± 
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ LJ7NfSRev( cTipoEnti, cFilPedAtu, cPedAtu, cOrcRes,;      º±±
±±           ³             		cSF1Doc, cSF1Serie )                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³TipoEnti - Tipo da Entidade.									º±±
±±           ³cOrcRes - Numero de Orcamento gerado pelo SIGALOJA.         º±±
±±           ³cSF1Fil - Filial da NF de Entrada Atual.                    º±±
±±           ³cSF1Doc - Numero da NF de Entrada Atual.                    º±±
±±           ³cSF1Serie - Serie da NF de Entrada Atual.                   º±±
±±           ³cUFCli - Estado do cliente da venda.  		                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Static Function LJ7NfSRev(cTipoEnti, cOrcRes, cSF1Fil,; 
								cSF1Doc, cSF1Serie, cUFCli, lRet)

Local aArea     	:= GetArea()
Local aAreaSF4  	:= SF4->(GetArea())
Local aAreaSF1  	:= SF1->(GetArea())
Local aAreaSD1  	:= SD1->(GetArea())
Local aCabec		:= {}
Local aItens		:= {}
Local aRegSD2		:= {}
Local aDocOri		:= {}
Local aItemOri		:= {}
Local aStruSF2  	:= SF2->(dbStruct())
Local aStruSD2  	:= SD2->(dbStruct())
Local cFilCdLoc		:= "" //Filial CD Local
Local cCliNF		:= "" //Cliente para Devolucao da NF de Transferencia - CD Local
Local cLojaNF		:= "" //Loja do Cliente para Devolucao da NF de Transferencia - CD Local
Local cFilLoja		:= Lj7FilLoja(cOrcRes) //Filial Loja da Venda
Local cAliasTmp		:= GetNextAlias()
Local cSerNf		:= SuperGetMv("MV_LJSERVF", Nil, "1") //Serie da NF VFE  
Local cFilBkp		:= cFilAnt
Local nY			:= 0
Local nX			:= 0
Local cTesDoc		:= ""
Local cCfop			:= ""
Local cNumNf		:= "" //Codigo da Nota de Devolucao
Local cItem			:= "00" //Item da Nota de Devolucao

//Para Filial do CD Local, primeiro busca campo prioritario
cFilCdLoc := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local

//Se nao encontrar prioritario, busca CD Local do Estado(UF)
If Empty(cFilCdLoc)	
	cFilCdLoc := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
EndIf	

//Cliente para Devolucao da NF de Transferencia - CD Local
cCliNF := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[2] 

//Se nao encontrar prioritario, busca CD Local do Estado(UF)
If Empty(cCliNF)	
	cCliNF := LJ7InfEnt(cEmpAnt, cUFCli, "1")[2] 
EndIf

//Loja do Cliente para Devolucao da NF de Transferencia - CD Local
cLojaNF := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[3] 

//Se nao encontrar prioritario, busca CD Local do Estado(UF)
If Empty(cLojaNF)	
	cLojaNF := LJ7InfEnt(cEmpAnt, cUFCli, "1")[3] 
EndIf

SF4->(dbSetOrder(1)) //F4_FILIAL+F4_CODIGO
SF1->(dbSetOrder(1)) //F1_FILIAL+F1_DOC+F1_SERIE+F1_FORNECE+F1_LOJA+F1_TIPO
SD1->(dbSetOrder(1)) //D1_FILIAL+D1_DOC+D1_SERIE+D1_FORNECE+D1_LOJA+D1_COD+D1_ITEM

//Condicional para a query		
cWhere := "% "
cWhere += " C5_FILIAL = " + "'" + cFilCdLoc + "'"
cWhere += " AND C5_ORCRES = " + "'" + cOrcRes + "'"
cWhere += " AND C5_TPCD = " + "'" + cTipoEnti + "'"
cWhere += " AND F1_FILIAL = " + "'" + cFilLoja + "'"
cWhere += " AND SC5.D_E_L_E_T_ = '' "   		   		
cWhere += " AND SF1.D_E_L_E_T_ = '' "	
cWhere += " %"              											
                                          
//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		C5_NUM, C5_CLIENTE, C5_LOJACLI, D1_FILIAL, D1_TES, D1_DOC, D1_SERIE
	FROM %table:SC5% SC5						
	INNER JOIN %table:SF1% SF1
		ON C5_FILIAL = F1_FILPV AND C5_NUM = F1_NUMPV
	INNER JOIN %table:SD1% SD1	
		ON F1_FILIAL = D1_FILIAL AND F1_DOC = D1_DOC AND F1_SERIE = D1_SERIE
		WHERE %exp:cWhere%
		GROUP BY C5_NUM, C5_CLIENTE, C5_LOJACLI, D1_FILIAL, D1_TES, D1_DOC, D1_SERIE 			
EndSql			

//Posiciona no inicio do arquivo temporario
(cAliasTmp)->(dbGoTop())

//Altera filial do CD Local
cFilAnt := cFilCdLoc

//Armazena informacoes da Venda
If (cAliasTmp)->(!EOF())		
	//Gera Nota de Devolucao
	If SF4->(dbSeek(xFilial("SF4") + (cAliasTmp)->D1_TES)) 
		cTesDoc := SF4->F4_TESDV
		
		//Posiciona na TES de Devolucao para pegar CFOP
		If SF4->(dbSeek(xFilial("SF4") + cTesDoc))
			cCfop := SF4->F4_CF
		EndIf
		
		//Altera filial Nota de Devolucao
		cFilAnt := cSF1Fil
										
		//Posiciona na NF de Entrada Atual
		If SF1->(dbSeek(xFilial("SF1") + cSF1Doc + cSF1Serie))
			//Adiciona Cabecalho da NF de Devolucao	
			For nX := 1 To Len(aStruSF2)
				Do Case
					Case AllTrim(aStruSF2[nX][1]) == "F2_FILIAL"						
						aAdd(aCabec, (cAliasTmp)->D1_FILIAL)
					Case AllTrim(aStruSF2[nX][1]) == "F2_SERIE"
						aAdd(aCabec, cSerNf)
					Case AllTrim(aStruSF2[nX][1]) == "F2_CLIENTE"
						aAdd(aCabec, cCliNf)
					Case AllTrim(aStruSF2[nX][1]) == "F2_LOJA"
						aAdd(aCabec, cLojaNf)
					Case AllTrim(aStruSF2[nX][1]) == "F2_TIPO"
						aAdd(aCabec, "D")
					Case AllTrim(aStruSF2[nX][1]) == "F2_EMISSAO"
						aAdd(aCabec, dDataBase)
					Case AllTrim(aStruSF2[nX][1]) == "F2_EST"
						aAdd(aCabec, SF1->F1_EST)
					Case AllTrim(aStruSF2[nX][1]) == "F2_ESPECIE"
						aAdd(aCabec, SF1->F1_ESPECIE)
					Case AllTrim(aStruSF2[nX][1]) == "F2_VALMERC"
						aAdd(aCabec, SF1->F1_VALMERC)
					Case AllTrim(aStruSF2[nX][1]) == "F2_VALBRUT"
						aAdd(aCabec, SF1->F1_VALBRUT)
					Case AllTrim(aStruSF2[nX][1]) == "F2_FRETE"
						aAdd(aCabec, SF1->F1_FRETE)
					Case AllTrim(aStruSF2[nX][1]) == "F2_DESCONT"
						aAdd(aCabec, SF1->F1_DESCONT)
					Case AllTrim(aStruSF2[nX][1]) == "F2_BASEICM"
						aAdd(aCabec, SF1->F1_BASEICM)						
					Case AllTrim(aStruSF2[nX][1]) == "F2_BASEIPI"
						aAdd(aCabec, SF1->F1_BASEIPI)
					Case AllTrim(aStruSF2[nX][1]) == "F2_COND"
						aAdd(aCabec, SF1->F1_COND)
					Case AllTrim(aStruSF2[nX][1]) == "F2_NFORI"
						aAdd(aCabec, (cAliasTmp)->D1_DOC)
					Case AllTrim(aStruSF2[nX][1]) == "F2_SERIORI"
						aAdd(aCabec, (cAliasTmp)->D1_SERIE)					
					OtherWise
						If aStruSF2[nX][2] $ "C/M"	
							aAdd(aCabec, "")
						ElseIf aStruSF2[nX][2] == "D"	
							aAdd(aCabec, CToD(""))
						ElseIf aStruSF2[nX][2] == "N"	
							aAdd(aCabec, 0)
						ElseIf aStruSF2[nX][2] == "L"	
							aAdd(aCabec, .F.)
						EndIf
				EndCase
			Next nX
					
			//Adiciona Itens da NF de Devolucao																																		
			If SD1->(dbSeek(SF1->(F1_FILIAL + F1_DOC + F1_SERIE)))
				While SD1->(!EOF()) .And. SD1->(D1_FILIAL + D1_DOC + D1_SERIE) == SF1->(F1_FILIAL + F1_DOC + F1_SERIE)								
					aAdd(aDocOri, 0)
					aAdd(aItens, {})					
					nY ++
					cItem := Soma1(cItem)					
																																																																		
					//Adiciona itens da NF
					For nX := 1 To Len(aStruSD2)																										
						Do Case
							Case AllTrim(aStruSD2[nX][1]) == "D2_FILIAL"																
								aAdd(aItens[nY], (cAliasTmp)->D1_FILIAL)
							Case AllTrim(aStruSD2[nX][1]) == "D2_ITEM"
								aAdd(aItens[nY], cItem)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_QUANT"
								aAdd(aItens[nY], SD1->D1_QUANT)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_COD"
								aAdd(aItens[nY], SD1->D1_COD)
							Case AllTrim(aStruSD2[nX][1]) == "D2_LOCAL"
								aAdd(aItens[nY], SD1->D1_LOCAL)	
							Case AllTrim(aStruSD2[nX][1]) == "D2_UM"
								aAdd(aItens[nY], SD1->D1_UM)																					
							Case AllTrim(aStruSD2[nX][1]) == "D2_PRCVEN"
								aAdd(aItens[nY], SD1->D1_VUNIT)	
							Case AllTrim(aStruSD2[nX][1]) == "D2_DESC"
								aAdd(aItens[nY], SD1->D1_VALDESC)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_TOTAL"
								aAdd(aItens[nY], SD1->D1_TOTAL)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_TES"
								aAdd(aItens[nY], cTesDoc)
							Case AllTrim(aStruSD2[nX][1]) == "D2_CF"
								aAdd(aItens[nY], cCfop)																							
							Case AllTrim(aStruSD2[nX][1]) == "D2_PICM"
								aAdd(aItens[nY], SD1->D1_PICM)	
							Case AllTrim(aStruSD2[nX][1]) == "D2_IPI"
								aAdd(aItens[nY], SD1->D1_IPI)																						
							Case AllTrim(aStruSD2[nX][1]) == "D2_TIPO"
								aAdd(aItens[nY], "D")		
							Case AllTrim(aStruSD2[nX][1]) == "D2_CLIENTE"
								aAdd(aItens[nY], cCliNf)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_LOJA"
								aAdd(aItens[nY], cLojaNf)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_QTDEDEV"
								aAdd(aItens[nY], SD1->D1_QUANT)								
							Case AllTrim(aStruSD2[nX][1]) == "D2_VALDEV"
								aAdd(aItens[nY], SD1->D1_TOTAL)									
							Case AllTrim(aStruSD2[nX][1]) == "D2_BASEICM"
								aAdd(aItens[nY], SD1->D1_BASEICM)									
							Case AllTrim(aStruSD2[nX][1]) == "D2_EMISSAO"
								aAdd(aItens[nY], dDataBase)									
							Case AllTrim(aStruSD2[nX][1]) == "D2_NFORI"
								aAdd(aItens[nY], (cAliasTmp)->D1_DOC)	
							Case AllTrim(aStruSD2[nX][1]) == "D2_SERIORI"
								aAdd(aItens[nY], (cAliasTmp)->D1_SERIE)																													
							OtherWise
								If aStruSD2[nX][2] $ "C/M"	
									aAdd(aItens[nY], "")
								ElseIf aStruSD2[nX][2] == "D"	
									aAdd(aItens[nY], CToD(""))
								ElseIf aStruSD2[nX][2] == "N"	
									aAdd(aItens[nY], 0)
								ElseIf aStruSD2[nX][2] == "L"	
									aAdd(aItens[nY], .T.)			
								EndIf								
						EndCase																			
					Next nX																		
																						
					SD1->(dbSkip())
				EndDo
			EndIf						
			
			//Altera filial
			cFilAnt := (cAliasTmp)->D1_FILIAL
															
			//Inclusao da NF de Devolucao                                                      				
			cNumNf := MaNfs2Nfs(,, (cAliasTmp)->C5_CLIENTE, (cAliasTmp)->C5_LOJACLI,; 
										cSerNf,,,,,,,,,,,,{|| aRegSD2}, {||}, aDocOri, aItens, aCabec,	.T.,  {|| .T.},  {|| .T.}, {|| .T.})
										
			//Verifica se ocorreram erros na geracao da NF de Devolucao
			If Empty(cNumNf)
				lRet := .F.
			EndIf																
		EndIf
	Else
		MsgAlert(STR0039 + (cAliasTmp)->D1_TES + STR0040 + xFilial("SF4") + STR0041 +; //"Atenção! TES: " #//" não cadastrada na filial: " ##//" ou não cadastrado campo TES de Devolução - F4_TESDV, "
					STR0042 + (cAliasTmp)->C5_NUM + STR0043) //"Geração da NF de Devolução para o Pedido de Venda original: " #//" não efetuada."	
					
		lRet := .F.
	EndIf
EndIf

//Fecha Alias temporario
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf

//Restaura filial
cFilAnt := cFilBkp

//Restaura a entrada da rotina                                    
RestArea(aAreaSF4)
RestArea(aAreaSF1)
RestArea(aAreaSD1)
RestArea(aArea)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7NccRev   ºAutor³Vendas Clientes     º Data ³  09/10/14   º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Gera NCC para o cliente no processo de Logistica Reversa.  º±± 
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ LJ7NccRev( cSF1Fil, cSF1Doc, cSF1Serie, cFilLoja)		    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cSF1Fil - Filial do Documento de Entrada						º±±
±±           ³cSF1Doc - Numero do Documento de Entrada						º±±
±±           ³cSF1Serie - Filial do Documento de Entrada.                 º±±
±±           ³cFilNCC - Filial para geracao da NCC.                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function LJ7NccRev(cSF1Fil, cSF1Doc, cSF1Serie, cFilNcc)

Local aArea     	:= GetArea()
Local aAreaSE1  	:= SE1->(GetArea())
Local aAreaSF1  	:= SF1->(GetArea())
Local aDadosNcc	:= {}
Local cNumTitulo 	:= GetSx8Num("SE1", "E1_NUM")
Local cFilBkp		:= cFilAnt
Local cNatNcc		:= SuperGetMv("MV_NATNCC", Nil, "CREDITO") //Natureza da NCC gerada 
Local dVenctoNcc	:= SuperGetMv("MV_LJDTNCC", Nil, 0) //Data de vencimento da NCC
Local cPreNcc		:= SuperGetMv("MV_LJNCVFE", Nil, "NCC") //Prefixo da NCC gerada 

Private lMsErroAuto := .F.

//Altera filial
cFilAnt := cSF1Fil

SF1->(dbSetOrder(1)) //F1_FILIAL+F1_DOC+F1_SERIE+F1_FORNECE+F1_LOJA+F1_TIPO

If SF1->(dbSeek(xFilial("SF1") + cSF1Doc + cSF1Serie))
	//Carrega dados do Titulo NCC
	aAdd(aDadosNcc, {"E1_PREFIXO"	, cPreNcc					, Nil})
	aAdd(aDadosNcc, {"E1_NUM"		, cNumTitulo				, Nil})
	aAdd(aDadosNcc, {"E1_PARCELA"	, "1"						, Nil})
	aAdd(aDadosNCC, {"E1_TIPO"		, "NCC"					, Nil})
	aAdd(aDadosNCC, {"E1_NATUREZ"	, cNatNcc					, Nil})
	aAdd(aDadosNCC, {"E1_CLIENTE"	, SF1->F1_FORNECE			, Nil})
	aAdd(aDadosNCC, {"E1_LOJA"		, SF1->F1_LOJA			, Nil})
	aAdd(aDadosNCC, {"E1_EMISSAO"	, dDatabase				, Nil})
	aAdd(aDadosNCC, {"E1_VENCTO"	, dDataBase + dVenctoNcc	, Nil})
	aAdd(aDadosNCC, {"E1_VENCREA"	, dDatabase + dVenctoNcc	, Nil})
	aAdd(aDadosNCC, {"E1_VALOR"		, SF1->F1_VALBRUT			, Nil})
	aAdd(aDadosNCC, {"E1_VLCRUZ"	, SF1->F1_VALBRUT			, Nil})

	//Altera filial da NCC
	cFilAnt := cFilNcc
	
	//Gera o Titulo de NCC com MsExecAuto
	MsExecAuto({|x, y| Fina040(x, y)}, aDadosNCC, 3) 	
	
	//Verifica erros na gravacao
	If lMsErroAuto
		RollbackSx8()
		MostraErro()
	Else
		ConfirmSx8()
	EndIf		
EndIf

//Restaura filial
cFilAnt := cFilBkp

//Restaura a entrada da rotina                                    
RestArea(aAreaSE1)
RestArea(aAreaSF1)
RestArea(aArea)

Return Nil		

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7CargPV  ºAutor³Vendas Clientes     º Data ³  10/10/14    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua carga no aCols e aHeader para geracoes dos Pedidos  º±± 
±±           ³ de Vendas.                                                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ Lj7CargPV( aSC5, aSC6, cSF1Ped, cNumPed )                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³aSC5 - aHeader para geracao do Pedido de Vendas. 	    	º±±
±±           ³aSC6 - aCols para geracao do Pedido de Vendas. 				º±±
±±           ³cSF1Fil - Filial do Documento de Entrada inicial				º±±
±±           ³cSF1Doc - Numero do Documento de Entrada inicial 			º±±
±±           ³cSF1Serie - Serie do Documento de Entrada inicial 			º±±
±±           ³cSC5Fil - Numero do Pedido de Venda.             			º±±
±±           ³cSC5Num - Numero do Pedido de Venda.             			º±±
±±           ³lCen1VFE - Indica se Cenario 1.                   			º±±
±±           ³cProcesso - Indica se processo Manual ou Automatico.  		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function Lj7CargPV(aSC5, aSC6, cSF1Fil, cSF1Doc, cSF1Serie, cSC5Fil,; 
								cSC5Num, lCen1VFE, cProcesso)

Local aArea     	:= GetArea()
Local aAreaSC5  	:= SC5->(GetArea())
Local aAreaSC6  	:= SC6->(GetArea())
Local aAreaSD1  	:= SD1->(GetArea())
Local aHeadSC5 		:= {}
Local aHeadSC6		:= {}
Local nX			:= 0
Local nY			:= 0
Local nUsado		:= 0
Local cNumPed		:= ""
Local cTpCd 		:= ""
Local cTesPed		:= ""
Local cCfop			:= ""
Local cFilPed		:= ""
Local cItemPed		:= "00"
Local cFilBkp 		:= cFilAnt //Armazena filial original

aSC5 := {}
aSC6 := {}

SX3->(dbSetOrder(1)) //X3_ARQUIVO+X3_ORDEM
SC5->(dbSetOrder(1))
SC6->(dbSetOrder(1))
SD1->(dbSetOrder(1))

//Busca campos SC5 no dicionario de dados
SX3->(dbSeek("SC5", .T.))
	
While SX3->(!Eof()) .And. SX3->X3_ARQUIVO == "SC5"
	If (X3Uso(SX3->X3_USADO) .And. cNivel >= SX3->X3_NIVEL;
			.And. SX3->X3_CONTEXT <> "V") .Or.	AllTrim(SX3->X3_CAMPO) == "C5_FILIAL" .Or.; 
			AllTrim(SX3->X3_CAMPO) == "C5_ORCRES"
		
		aAdd(aHeadSC5, AllTrim(SX3->X3_CAMPO))		
	EndIf
	
	SX3->(dbSkip())
EndDo

//Busca campos SC6 no dicionario de dados
SX3->(dbSeek("SC6", .T.))
	
While SX3->(!Eof()) .And. SX3->X3_ARQUIVO == "SC6"
	If (X3Uso(SX3->X3_USADO) .And. cNivel >= SX3->X3_NIVEL;
			.And. SX3->X3_CONTEXT <> "V") .Or. AllTrim(SX3->X3_CAMPO) == "C6_FILIAL"
							
		aAdd(aHeadSC6, AllTrim(SX3->X3_CAMPO))
	EndIf
	
	SX3->(dbSkip())
EndDo

//Numero do Pedido de Venda
cNumPed := GetSxeNum("SC5", "C5_NUM")

//Processo Automatico de Pedido de Venda
If cProcesso == "A"
	//Cenario 1	
	If lCen1VFE 
		cTpCd := "2"
	Else //Cenario 2
		cTpCd := "5"
	EndIf		
	
	//Altera filial da Venda Original
	cFilAnt := cSC5Fil
							
	//Posiciona no Pedido de Vendas Original
	If SC5->(dbSeek(xFilial("SC5") + cSC5Num))
		
		//Se tipo do Pedido == 3, deve buscar a filial da loja
		If SC5->C5_TPCD == "3"
			cFilPed := Lj7FilLoja(SC5->C5_ORCRES) //Filial - Loja da Venda	 			
		Else
			cFilPed := SC5->C5_FILIAL
		EndIf				
	
		//Armazena informacoes SC5
		For nX := 1 To Len(aHeadSC5)
			Do Case
				Case AllTrim(aHeadSC5[nX]) == "C5_FILIAL"
					aAdd(aSC5, {aHeadSC5[nX], cFilPed, Nil})
				Case AllTrim(aHeadSC5[nX]) == "C5_NUM"
					aAdd(aSC5, {aHeadSC5[nX], cNumPed, Nil})
				Case AllTrim(aHeadSC5[nX]) == "C5_TPCD"
					aAdd(aSC5, {aHeadSC5[nX], cTpCd, Nil})
				Case AllTrim(aHeadSC5[nX]) == "C5_EMISSAO"
					aAdd(aSC5, {aHeadSC5[nX], dDataBase, Nil})
				OtherWise
					aAdd(aSC5, {aHeadSC5[nX], SC5->&(aHeadSC5[nX]), Nil})					
			EndCase		                     																												
		Next nX
		
		//Restaura filial original
		cFilAnt := cFilBkp
		
		//Monta aCols buscando Itens na NF Original					
		If SD1->(dbSeek(SF1->(F1_FILIAL + F1_DOC + F1_SERIE)))
			//Preenche o Acols do Pedido de Venda                                     		
			nUsado := Len(aHeadSC6)
			
			While SD1->(!EOF()) .And. SD1->(D1_FILIAL + D1_DOC + D1_SERIE) == SF1->(F1_FILIAL + F1_DOC + F1_SERIE)																	
				//Busca Tes										
				If cTpCd == "2"
					cTesPed := SuperGetMv("MV_LJPEDEF",, "")                                                                                          
			
					If !Empty(cTesPed)
						If Substr(cTesPed, 1, 1) == "&"
			        		cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))			    			    			     				   
			    		EndIf
			   		EndIf			   				   	
				Else
					//Busca Tes no Item do Documento de Saida Origem
					cTesPed := Posicione("SD2", 3, xFilial("SD2") + SD1->D1_NFORI + SD1->D1_SERIORI + SC5->C5_CLIENTE + SC5->C5_LOJACLI + SD1->D1_COD + SD1->D1_ITEMORI, "D2_TES")
				EndIf
				
				//Posiciona registros                                                     						
				SB1->(dbSeek(xFilial("SB1") + SD1->D1_COD))							
				
				//Se Tes Nao informada, busca TES Inteligente
				If Empty(cTesPed)
					cTesPed := MaTESInt(2, "01", SC5->C5_CLIENTE, SC5->C5_LOJACLI, "C", SB1->B1_COD)										
				EndIf			
														
				//Posiciona na TES para pegar CFOP
				If SF4->(dbSeek(xFilial("SF4") + cTesPed))
					cCfop := SF4->F4_CF
				EndIf
				 					
				aAdd(aSC6, Array(nUsado + 1))
				nY := Len(aSC6)
				aSC6[nY, nUsado + 1] := .F.					
				
				//Armazena informacoes SC6
				For nX := 1 To Len(aHeadSC6)
					Do Case
						Case AllTrim(aHeadSC6[nX]) == "C6_FILIAL"
							aSC6[nY, nX] := {aHeadSC6[nX], cFilPed, Nil} 
						Case AllTrim(aHeadSC6[nX]) == "C6_NUM"
							aSC6[nY, nX] := {aHeadSC6[nX], cNumPed, Nil} 
						Case AllTrim(aHeadSC6[nX]) == "C6_ITEM"
							cItemPed := Soma1(cItemPed)								
							aSC6[nY, nX] := {aHeadSC6[nX], cItemPed, Nil}  
						Case AllTrim(aHeadSC6[nX]) == "C6_PRODUTO"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_COD, Nil}
						Case AllTrim(aHeadSC6[nX]) == "C6_UM"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_UM, Nil}
						Case AllTrim(aHeadSC6[nX]) == "C6_QTDVEN"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_QUANT, Nil}
						Case AllTrim(aHeadSC6[nX]) == "C6_PRCVEN"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_VUNIT, Nil}          
						Case AllTrim(aHeadSC6[nX]) == "C6_VALOR"    
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_TOTAL, Nil}
						Case AllTrim(aHeadSC6[nX]) == "C6_TES"
							aSC6[nY, nX] := {aHeadSC6[nX], cTesPed, Nil}	
						Case AllTrim(aHeadSC6[nX]) == "C6_CF"
							aSC6[nY, nX] := {aHeadSC6[nX], cCfop, Nil}																																					
						Case AllTrim(aHeadSC6[nX]) == "C6_LOCAL"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_LOCAL, Nil}							
						Case AllTrim(aHeadSC6[nX]) == "C6_DESCRI"
							aSC6[nY, nX] := {aHeadSC6[nX], SB1->B1_DESC, Nil}
						Case AllTrim(aHeadSC6[nX]) == "C6_PRUNIT"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_VUNIT, Nil}											
						Case AllTrim(aHeadSC6[nX]) == "C6_QTDLIB"
							aSC6[nY, nX] := {aHeadSC6[nX], SD1->D1_QUANT, Nil}
						Case AllTrim(aHeadSC6[nX]) == "C6_QTDEMP"
							aSC6[nY, nX] := {aHeadSC6[nX], 0, Nil}
						OtherWise	
							aSC6[nY, nX] := {aHeadSC6[nX], CriaVar(aHeadSC6[nX], .T.), Nil}									 
					EndCase
				Next nX
							
				SD1->(dbSkip())
			EndDo
		EndIf	
	EndIf
Else //Processo Manual de Pedido de Venda
	//Posiciona na Filial do Pedido de Venda
	cFilAnt := cSC5Fil
	
	//Posiciona no Pedido de Vendas que acabou de ser gerado
	If SC5->(dbSeek(xFilial("SC5") + cSC5Num))
		//Armazena informacoes SC5
		For nX := 1 To Len(aHeadSC5)
			Do Case
				Case AllTrim(aHeadSC5[nX]) == "C5_NUM"
					aAdd(aSC5, {aHeadSC5[nX], cNumPed, Nil})				
				OtherWise
					aAdd(aSC5, {aHeadSC5[nX], SC5->&(aHeadSC5[nX]), Nil})					
			EndCase		                     																												
		Next nX
		
		If SC6->(dbSeek(SC5->(C5_FILIAL + C5_NUM)))
			//Preenche o Acols do Pedido de Venda                                     		
			nUsado := Len(aHeadSC6)
			
			While SC6->(!EOF()) .And. SC6->(C6_FILIAL + C6_NUM) == SC5->(C5_FILIAL + C5_NUM)
				//aAdd(aSC6, {})
				aAdd(aSC6, Array(nUsado + 1))
				nY := Len(aSC6)				
				aSC6[nY, nUsado + 1] := .F.
				
				//Armazena informacoes SC6
				For nX := 1 To Len(aHeadSC6)								
					Do Case
						Case AllTrim(aHeadSC6[nX]) == "C6_NUM"
							aSC6[nY, nX] := {aHeadSC6[nX], cNumPed, Nil} 									
						OtherWise						
							aSC6[nY, nX] := {aHeadSC6[nX], SC6->&(aHeadSC6[nX]), Nil}
					EndCase
				Next nX
				
				SC6->(dbSkip())
			EndDo
		EndIf
	EndIf
EndIf	

//Restaura filial original
cFilAnt := cFilBkp
			
//Restaura a entrada da rotina                                    
RestArea(aAreaSC5)
RestArea(aAreaSC6)
RestArea(aAreaSD1)
RestArea(aArea)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7PVManu  ºAutor³Vendas Clientes     º Data ³  10/10/14    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Efetua carga no aCols para manipulacao e geracao do Pedido º±± 
±±           ³ de Vendas Remessa Entrega Futura na Logistica Reversa.     º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ Lj7PVManu( aHeadC6, aSC6, cSF1Doc,;                        º±±
±±           ³					cSF1Serie, cFilLoja )			           º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³aSC5 - Dados do SC5 para geracao do Pedido de Vendas. 		º±±
±±           ³aSC6 - Dados do SC6 para geracao do Pedido de Vendas. 		º±±
±±           ³cSF1Fil - Filial do Documento de Entrada						º±±
±±           ³cSF1Doc - Numero do Documento de Entrada						º±±
±±           ³cSF1Serie - Filial do Documento de Entrada.                 º±±
±±           ³cOrcRes - Orcamento gerado no SIGALOJA.                     º±±
±±           ³cUFCli - Estado do Cliente da Venda.                       º±±
±±           ³cFilPed - Filial do Pedido de Venda original.               º±±
±±           ³cPedido - Numero do Pedido de Venda original.               º±±
±±           ³cTpEnti - Tipo do Pedido de Venda Original.                 º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function Lj7PVManu(aSC5, aSC6, cSF1Fil, cSF1Doc, cSF1Serie,;
								cOrcRes, cUFCli, cFilPed, cPedido, cTpEnti)

Local aArea     := GetArea()
Local aAreaSA1  := SA1->(GetArea())
Local aAreaSB1  := SB1->(GetArea())
Local aAreaSC5  := SC5->(GetArea())
Local aAreaSC6  := SC6->(GetArea())
Local aAreaSF4  := SF4->(GetArea())
Local aAreaSF1  := SF1->(GetArea())
Local aAreaSD1  := SD1->(GetArea())
Local bCampo    := {|nCPO| Field(nCPO)}
Local nX        := 0
Local nY        := 0
Local nMaxFor   := 0
Local nUsado    := 0
Local nRet		:= 0
Local cNumPed	:= ""
Local cTesPed	:= ""
Local cCfop		:= ""
Local lCen1VFE  := LjAnalisaLeg(69)[1] .And. SuperGetMv("MV_LJC1VFE", Nil, .F.) //Especifico para Minas Gerais = Cenario 1 - Loja da Venda
Local cFilLoja  := "" //Filial Loja da Venda
Local cItemPed  := "00" //Item do Pedido
Local cTpCarga  := If(SuperGetMV("MV_LJGCOMS", NIL, .F.),"1", "2")// Carga  1-Utiliza \ 2-Nao utiliza
Local cFilBkp	:= cFilAnt
Local aHeadC6	:= {}

//Se a Loja da Venda Cenario 1, verifica se cliente tambem Cenario 1
If lCen1VFE
	//Verifica cenario de venda VFE para o cliente
	lCen1VFE := LjAnalisaLeg(69, cUFCli)[1] .And. SuperGetMv("MV_LJC1VFE", Nil, .F.) //Especifico para Minas Gerais = Cenario 1 - Cliente
EndIf

//Inicializa variaveis
aSC5 := {}		
aSC6 := {}

//Variaveis Utilizadas pela Funcao a410Inclui
Private aHeader		:= {}
Private aCols 		:= {}          
Private aHeadGrade 	:= {}
Private aColsGrade 	:= {}
Private n          	:= 1
Private ALTERA 		:= .T.
Private INCLUI 		:= .T.
Private cCadastro 	:= STR0044 //"Pedido de Venda"

SF1->(dbSetOrder(1)) //F1_FILIAL+F1_DOC+F1_SERIE+F1_FORNECE+F1_LOJA+F1_TIPO
SD1->(dbSetOrder(1)) //D1_FILIAL+D1_DOC+D1_SERIE+D1_FORNECE+D1_LOJA+D1_COD+D1_ITEM
SX3->(dbSetOrder(1))	//X3_ARQUIVO+X3_ORDEM
SA1->(dbSetOrder(1)) //A1_FILIAL+A1_COD+A1_LOJA 
SB1->(dbSetOrder(1))	//B1_FILIAL+B1_COD
SF4->(dbSetOrder(1)) //F4_FILIAL+F4_CODIGO
SC5->(dbSetOrder(1)) 

//Altera filial
cFilAnt := cSF1Fil

If SF1->(dbSeek(xFilial("SF1") + cSF1Doc + cSF1Serie))			
	//Monta aHeader	
	SX3->(dbSeek("SC6", .T.))
	
	//Busca campos SC6 no dicionario de dados	
	While SX3->(!Eof()) .And. SX3->X3_ARQUIVO == "SC6"
		If (X3Uso(SX3->X3_USADO) .And.;					
				cNivel >= SX3->X3_NIVEL .And.;
				SX3->X3_TIPO <> "M") 
	
			aAdd(aHeadC6, {	AllTrim(SX3->X3_TITULO),;
								SX3->X3_CAMPO,;
								SX3->X3_PICTURE,;
								SX3->X3_TAMANHO,;
								SX3->X3_DECIMAL,;
								SX3->X3_VALID,;
								SX3->X3_USADO,;
								SX3->X3_TIPO,;
								SX3->X3_ARQUIVO,;
								SX3->X3_CONTEXT})
		EndIf
		
		SX3->(dbSkip())
	EndDo
						
	//Cria as variaveis do Pedido de Venda                                    		
	dbSelectArea("SC5")
	
	nMaxFor := FCount()
	
	For nX := 1 To nMaxFor
		M->&(EVAL(bCampo,nX)) := CriaVar(FieldName(nX), .T.)
	Next nX				
	
	cNumPed := GetSxeNum("SC5", "C5_NUM")
	
	//Posiciona no Pedido de Venda original	
	SC5->(dbSeek(cFilPed + cPedido))
	
	//Atualiza cabecalho do Pedido de Venda
	M->C5_NUM		:= cNumPed				
	M->C5_CLIENTE 	:= SC5->C5_CLIENTE
	M->C5_LOJACLI 	:= SC5->C5_LOJACLI	
	M->C5_CLIENT	:= SC5->C5_CLIENT
	M->C5_LOJAENT	:= SC5->C5_LOJAENT					                     					
	M->C5_CONDPAG 	:= SC5->C5_CONDPAG
	M->C5_TIPOCLI 	:= SC5->C5_TIPOCLI
	M->C5_VEND1		:= SC5->C5_VEND1	
	M->C5_MOEDA   	:= SC5->C5_MOEDA	
	M->C5_TPCARGA	:= cTpCarga
	
	//Classifica Tipo do Pedido de Venda conforme Estado da Venda
	//Cenario 1	
	If lCen1VFE 
		M->C5_TPCD	:= "2"
	Else //Cenario 2
		M->C5_TPCD	:= "5"
	EndIf
						
	//Preenche o Acols do Pedido de Venda                                     		
	nUsado := Len(aHeadC6)
	
	//Busca Itens na NF Original	
	If SD1->(dbSeek(SF1->(F1_FILIAL + F1_DOC + F1_SERIE)))
		While SD1->(!EOF()) .And. SD1->(D1_FILIAL + D1_DOC + D1_SERIE) == SF1->(F1_FILIAL + F1_DOC + F1_SERIE)																	
			//Busca Tes										
			If M->C5_TPCD == "2"
				cTesPed := SuperGetMv("MV_LJPEDEF",, "")                                                                                          
			
				If !Empty(cTesPed)
					If Substr(cTesPed, 1, 1) == "&"
			        	cTesPed := &(Substr(cTesPed, 2, Len(cTesPed)))			    			    			     				   
			    	EndIf
			   	EndIf			   				   	
			Else
				//Busca Tes no Item do Documento de Saida Origem
				cTesPed := Posicione("SD2", 3, xFilial("SD2") + SD1->D1_NFORI + SD1->D1_SERIORI + SC5->C5_CLIENTE + SC5->C5_LOJACLI + SD1->D1_COD + SD1->D1_ITEMORI, "D2_TES")
			EndIf
			
			//Posiciona produto                                                   						
			SB1->(dbSeek(xFilial("SB1") + SD1->D1_COD))
			
			//Se Tes Nao informada, busca TES Inteligente
			If Empty(cTesPed)
				cTesPed := MaTESInt(2, "01", SC5->C5_CLIENTE, SC5->C5_LOJACLI, "C", SB1->B1_COD)										
			EndIf				
										
			//Posiciona na TES de Devolucao para pegar CFOP
			If SF4->(dbSeek(xFilial("SF4") + cTesPed))
				cCfop := SF4->F4_CF
			EndIf
			
			aAdd(aSC6, Array(nUsado + 1))
			nY := Len(aSC6)		
			aSC6[nY, nUsado + 1] := .F.

			For nX := 1 To nUsado
				Do Case
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_NUM")
						aSC6[nY, nX] := cNumPed
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_ITEM")								
						cItemPed := Soma1(cItemPed)
						aSC6[nY, nX] := cItemPed
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_PRODUTO")
						aSC6[nY, nX] := SD1->D1_COD
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_UM")
						aSC6[nY, nX] := SD1->D1_UM
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_QTDVEN")
						aSC6[nY, nX] := SD1->D1_QUANT
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_PRCVEN")
						aSC6[nY, nX] := SD1->D1_VUNIT          
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_VALOR")    
						aSC6[nY,nX] := SD1->D1_TOTAL
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_TES")
						aSC6[nY, nX] := cTesPed	
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_CF")
						aSC6[nY, nX] := cCfop																																					
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_LOCAL")
						aSC6[nY, nX] := SD1->D1_LOCAL							
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_DESCRI")
						aSC6[nY, nX] := SB1->B1_DESC
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_PRUNIT")
						aSC6[nY, nX] := SD1->D1_VUNIT											
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_QTDLIB")
						aSC6[nY, nX] := SD1->D1_QUANT
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_NFORI")
						aSC6[nY, nX] := SD1->D1_DOC
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_SERORI")
						aSC6[nY, nX] := SD1->D1_SERIE									
					Case (AllTrim(aHeadC6[nX, 2]) == "C6_QTDEMP")
						aSC6[nY, nX] := 0						
					OtherWise
						aSC6[nY, nX] := CriaVar(aHeadC6[nX, 2], .T.)
				EndCase					
			Next nX
					
			SD1->(dbSkip())
		EndDo
	EndIf							
EndIf

//Se Pedido de Venda Manual, abre tela para Inclusao
If Len(aSC6) > 0		
	Begin Transaction
		aCols   := aClone(aSC6)
		aHeader := aClone(aHeadC6)															
				
		For nX := 1 To Len(aCols)
			MatGrdMont(nX)
		Next nX
		
		Pergunte("MTA410", .F.)		 
											  			
		nRet := SC5->(a410Inclui("SC5", SC5->(RECNO()), 3, .T.))
		
		//Atualiza OrcRes
		If nRet > 0
			SC5->(RecLock("SC5", .F.))
			SC5->C5_ORCRES := cOrcRes
			SC5->(MsUnlock())
		EndIf  
	End Transaction						
EndIf	

If nRet > 0 		
	Lj7CargPV(aSC5, aSC6,,,, SC5->C5_FILIAL, SC5->C5_NUM, lCen1VFE, "M")
EndIf

//Restaura filial
cFilAnt := cFilBkp
                                   
//Restaura a entrada da rotina                                    
RestArea(aAreaSA1)
RestArea(aAreaSB1)
RestArea(aAreaSC5)
RestArea(aAreaSC6)
RestArea(aAreaSF4)
RestArea(aAreaSF1)
RestArea(aAreaSD1)
RestArea(aArea)

Return nRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7GerPVRevºAutor³Vendas Clientes     º Data ³  10/10/14    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Gera os Pedidos de Venda para rotina de Logistica Reversa. º±± 
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ LJ7GerPVRev( cTipoPV, cOrcRes, aHeadC6, aSC6) 				º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cTipoPV - Tipo do Pedido de Venda.                    		º±±
±±           ³cOrcRes - Orcamento gerado no SIGALOJA.                    	º±±
±±           ³aSC5 - Dados do SC5 para gerar o Pedido de Venda.          	º±±
±±           ³aSC6 - Dados do SC6 para gerar o Pedido de Venda.			º±±
±±           ³cUFCli - Estado do Cliente da Venda.                       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil														       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Static Function LJ7GerPVRev(cTipoPV, cOrcRes, aSC5, aSC6, cUFCli, lRet)
									
Local aArea     	:= GetArea()
Local aAreaSC5  	:= SC5->(GetArea())
Local aAreaSC6  	:= SC6->(GetArea())
Local aAreaSC9  	:= SC9->(GetArea())
Local aAreaSF4  	:= SF4->(GetArea())
Local aCabPed		:= {}						//Cabeçalho Pedido
Local aLinhaPed	:= {}						//(1)Item Pedido
Local aItensPed	:= {}						//Itens Pedido
Local cFilBkp		:= cFilAnt					//Bkp Filial
Local cFilPed		:= "" 						//Filial do Pedido de Venda
Local cCliente 	:= ""						//Cliente do Pedido
Local cLoja		:= ""						//Loja do Cliente
Local cClient		:= ""						//Cliente para entrega
Local cLojEnt		:= ""						//Loja para entrega
Local cMenNota	:= ""						//Armazena o descricao do complemento da nota - rodape
Local cNumSC5		:= CriaVar("C5_NUM",.F.)	//Numero do Pedido - Inclusao
Local cMay			:= ""						//Verificar se nao esta utilizando a numeração
Local cTesPed    	:= ""                  	//Tes Pedido de Venda
Local cProdPed	:= ""						//Produto
Local cCfop		:= ""
Local cArmPed		:= "" 						//Armazem do Pedido
Local cFilLoja	:= ""						//Filial Loja da Venda
Local cTpCarga 	:= If(SuperGetMV("MV_LJGCOMS", NIL, .F.),"1", "2")// Carga  1-Utiliza \ 2-Nao utiliza
Local nPosFil		:= 0						//Posicao Filial
Local nPosCab		:= 0						//Posicao Cabecalho
Local nJ 			:= 0						//Contador
Local nI 			:= 0						//Contador
Local nY			:= 0						//Contador
Local nPos			:= 0						//Posicao do registro
Local nSaveSx8  	:= 0                                                  
Local nPrcVen		:= 0						//Preco de Venda
Local nQtdLib		:= 0						//Quantidade liberada do item	
Local nPrcItem	:= 0						//Preco do Item
Local nPerDesc	:= 0						//Percentual de Desconto
Local nValDesc	:= 0						//Valor de Desconto	
Local nPosFilC5	:= aScan(aSC5, {|x| AllTrim(Upper(x[1])) == "C5_FILIAL"})
Local nPosPed		:= aScan(aSC5, {|x| AllTrim(Upper(x[1])) == "C5_NUM"})
Local lLiber 		:= .F.						//Compatibilizacao com o SIGAFAT
Local lTransf		:= .F.      				//Compatibilizacao com o SIGAFAT	
Local lLiberOk 	:= .T.						//Compatibilizacao com o SIGAFAT
Local lResidOk 	:= .T.						//Compatibilizacao com o SIGAFAT		
Local lFaturOk 	:= .F.						//Compatibilizacao com o SIGAFAT	
Local lTLVReg  	:= .F.						//Compatibilizacao com o SIGAFAT 

Private lMSErroAuto := .F. //VerIfica se ocorreu algum erro durante a Geracao do PV

SF4->(dbSetOrder(1))

//Tipos de Pedido de Venda para Logistica Reversa VFE - MG
//2 - Remessa Entrega Futura
//3 - Remessa por conta e ordem de Estabelecimento Showroom
//4 - Transferencia Simbolica
//5 - Pedido de Venda - Cenario 2

//Armazena a filial para o Pedido de Venda							
If cTipoPV $ "2|3|5" //Remessa Entrega Futura, Remessa por conta e ordem de Estabelecimento Showroom ou Cenario 2	
	//Remessa por conta e ordem, busca filial do CD Local
	If cTipoPV == "3"				
		//Para Filial do CD Local, primeiro busca campo prioritario
		cFilPed := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cFilPed)	
			cFilPed := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
		EndIf	
	Else  
		cFilPed := aSC5[nPosFilC5, 2] //Filial - CD Local	
	EndIf
	
	cCliente 	:= SC5->C5_CLIENTE //Cliente
	cLoja		:= SC5->C5_LOJACLI //Loja
	cClient	:= SC5->C5_CLIENT  //Cliente para entrega
	cLojEnt	:= SC5->C5_LOJAENT //Loja para entrega
ElseIf cTipoPV == "4" //Transferencia Simbolica		
	//Para Filial do CD Local, primeiro busca campo prioritario
	cFilPed := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
	
	//Se nao encontrar prioritario, busca CD Local do Estado(UF)
	If Empty(cFilPed)	
		cFilPed := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
	EndIf	
										
	//Para Loja da Venda, busca diretamente na tabela SLJ pois podem haver varias lojas no Estado
	cFilLoja := Lj7FilLoja(cOrcRes)
	
	SLJ->(dbSetOrder(3))		
	SLJ->(dbSeek(xFilial("SLJ") + cEmpAnt + cFilLoja))
		
	cCliente := SLJ->LJ_CLIENTE //Cliente
	cLoja 	  := SLJ->LJ_LOJCLI //Loja                         
	cClient  := cCliente //Cliente para entrega                            
	cLojEnt  := cLoja //Loja para entrega
EndIf 							

//Posiciona no cliente do Pedido de Venda
SA1->(dbSetOrder(1))		
SA1->(dbSeek(xFilial("SA1") + cCliente + cLoja))
							
// Armazena Cab/SC5
For nI := 1 To Len(aSC5)
	Do Case		
		Case AllTrim(aSC5[nI, 1]) == "C5_NUM"			
			aAdd(aCabPed, {aSC5[nI, 1],	"", Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_CLIENTE"
			aAdd(aCabPed, {aSC5[nI, 1],	cCliente, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_LOJACLI"
			aAdd(aCabPed, {aSC5[nI, 1],	cLoja, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_CLIENT"
			aAdd(aCabPed, {aSC5[nI, 1],	cClient, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_LOJAENT"
			aAdd(aCabPed, {aSC5[nI, 1],	cLojEnt, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_EMISSAO"
			aAdd(aCabPed, {aSC5[nI, 1],	dDataBase, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_MENPAD"
			aAdd(aCabPed, {aSC5[nI, 1],	"", Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_TPCD"
			aAdd(aCabPed, {aSC5[nI, 1], cTipoPV, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_ORCRES"
			aAdd(aCabPed, {aSC5[nI, 1], cOrcRes, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_TIPOCLI"						
			aAdd(aCabPed, {aSC5[nI, 1], SA1->A1_TIPO, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_TPCARGA"
			aAdd(aCabPed, {aSC5[nI, 1], cTpCarga, Nil})
		Case AllTrim(aSC5[nI, 1]) == "C5_TRANSP"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})	
			Else
				aAdd(aCabPed, {aSC5[nI, 1], "", Nil})				
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_TPFRETE"
			If cTipoPV $ "2|5"				
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})
			Else
				aAdd(aCabPed, {aSC5[nI, 1], SA1->A1_TPFRET, Nil})	
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_FRETE"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})				
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})	
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_FRETAUT"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})	
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})				
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_RECFAUT"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})				
			Else
				aAdd(aCabPed, {aSC5[nI, 1], "", Nil})	
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_DESCONT"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})	
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})				
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_DESC1"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})	
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})				
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_DESC2"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})				
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})	
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_DESC3"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})				
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})	
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_DESC4"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})				
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})	
			EndIf
		Case AllTrim(aSC5[nI, 1]) == "C5_DESCFI"
			If cTipoPV $ "2|5"
				aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})				
			Else
				aAdd(aCabPed, {aSC5[nI, 1], 0, Nil})	
			EndIf			
		OtherWise
			aAdd(aCabPed, {aSC5[nI, 1], aSC5[nI, 2], Nil})	
	EndCase
Next nI

//Inicializa mensagem da Nota
cMenNota := ""

//Dados complementares no rodape
If cTipoPV $ "2|3"  
	//Altera filial para mensagem no Rodape do Pedido (Nesse caso inverte pois necessita das informacoes da outra filial)
	If cTipoPV == "2" //Remessa Entrega Futura				
		//Para Filial do CD Local, primeiro busca campo prioritario
		cFilAnt := LJ7InfEnt(cEmpAnt, cUFCli, "2", .T.)[1] //Filial CD Local
		
		//Se nao encontrar prioritario, busca CD Local do Estado(UF)
		If Empty(cFilAnt)	
			cFilAnt := LJ7InfEnt(cEmpAnt, cUFCli, "1")[1] //Filial CD Local	
		EndIf	
	Else
		cFilAnt := Lj7FilLoja(cOrcRes) //Filial Loja da Venda
	EndIf
	
	SM0->(dbSetOrder(1))
	SM0->(dbSeek(Subs(cEmpAnt, 1, 2) + cFilAnt))
	
	cMenNota := STR0001 + AllTrim(SM0->M0_ENDENT) +; //"Endereco: "
								STR0002 + AllTrim(SM0->M0_COMPENT) +; //", Complemento :"
								STR0003 + AllTrim(SM0->M0_BAIRENT) +; //", Bairro :"
								STR0004 + AllTrim(SM0->M0_CIDENT) +; //", Cidade :"
								STR0005 + AllTrim(SM0->M0_ESTENT) +; //", Estado :"
								STR0006 + SM0->M0_CEPENT+; //", CEP :"
						       STR0007 + SM0->M0_INSC + " , " +; //" ** Insc.Estadual: "
						       STR0008 + AllTrim(SM0->M0_NOMECOM) + " , " +; //" ** Razao Social: "
					   	       STR0009 + SM0->M0_CGC + "  " //" ** CNPJ "					   	      
	
	//Restaura filial
	cFilAnt := cFilBkp
	
	SM0->(dbSeek(Subs(cEmpAnt, 1, 2) + cFilAnt))	
EndIf							

aAdd(aCabPed, {"C5_MENNOTA", cMenNota, Nil}) 

//Altera Filial	
cFilAnt := cFilPed //Esse comando altera a Filial

nSaveSx8 := GetSx8Len()

//Numeração Pedido
If cTipoPV $ "2|5"
	cNumSC5 := aSC5[nPosPed, 2]
Else				
	cNumSC5 := GetSxeNum("SC5", "C5_NUM")
EndIf 

cMay := "SC5" + AllTrim(xFilial("SC5")) + cNumSC5

While !Eof() .AND. SC5->(DbSeek(xFilial("SC5") + cNumSC5) .OR. !MayIUseCode(cMay))
	cNumSC5 := Soma1(cNumSC5, Len(cNumSC5))
	cMay 	 := "SC5" + AllTrim(xFilial("SC5")) + cNumSC5
EndDo	
							
If __lSX8
	ConfirmSX8()
EndIf	
					
//Troca numeracao e filial
nPosFil := aScan(aCabPed , {|x| AllTrim(Upper(x[1])) == "C5_FILIAL"})
nPosCab := aScan(aCabPed , {|x| AllTrim(Upper(x[1])) == "C5_NUM"})
aCabPed[nPosFil][2] := cFilPed
aCabPed[nPosCab][2] := cNumSC5

//Grava Cabeçalho Pedido de Venda
If Len(aCabPed) > 0              
	SC5->(RecLock("SC5", .T.))
	
	For nJ := 1 To Len(aCabPed)		
 		SC5->&(aCabPed[nJ][1]) := aCabPed[nJ][2]
   	Next nJ    	   	   	      
   
   FkCommit() //Commit para integridade referencial do SC5	   	   	                                                  	  	
  	
  	//Checando o parametro de acordo com o tipo de chamada   											
	If cTipoPV == "3" //Remessa por Conta e Ordem de Estabelecimento Showroom
		cTesPed := SuperGetMv("MV_LJPEDRC",, "")                                                                                          
		
		If !Empty(cTesPed)
			If Substr(cTesPed, 1, 1) == "&"
	        	cTesPed  := &(Substr(cTesPed, 2, Len(cTesPed)))
    	    EndIf	    		    	
    	EndIf    
	ElseIf cTipoPV == "4" //Transferencia Simbolica
		cTesPed := SuperGetMv("MV_LJPEDTS",, "")                                                                                          
		
		If !Empty(cTesPed)
			If Substr(cTesPed, 1, 1) == "&"
	        	cTesPed  := &(Substr(cTesPed, 2, Len(cTesPed)))
    	    EndIf	    		    				    	
    	EndIf
    EndIf		        
				  		   													
	//Carrega itens do Pedido de Venda
	For nI := 1 To Len(aSC6)
		aLinhaPed := {} 	
		
		//Somente Pedidos de Venda tipo 3|4 - Remessa por Conta e Ordem|Transferencia Simbolica
		//Serao verificados conforme regras, os demais assumem as inforacoes enviadas no Pedido 
		//de Venda original
			
		For nY := 1 To Len(aSC6[nI]) - 1 //Ultimo elemento nao carrega pois controle de item deletado	
			Do Case
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_FILIAL"								
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), cFilPed, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_NUM"	
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), cNumSC5, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_PRODUTO"	
					cProdPed := aSC6[nI, nY, 2]					
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), cProdPed, Nil})										
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_TES" 						    			
	    			If cTipoPV $ "3|4"	    				    			
	    				//Se Tes Nao informada, busca TES Inteligente
	    				If Empty(cTesPed)
	    					cTesPed := MaTESInt(2, "01", cCliente, cLoja, "C", cProdPed)	    					    					
	    				EndIf
	    			Else
	    				cTesPed := aSC6[nI, nY, 2]
	    			EndIf
	    																								
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), cTesPed, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_CF"										 
					//Posiciona na TES de Devolucao para pegar CFOP
					If SF4->(dbSeek(FWxFilial("SF4",cFilPed)+ cTesPed))
						cCfop := SF4->F4_CF
					EndIf										
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), cCfop, Nil})				
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_PRCVEN"
					If cTipoPV $ "3|4"
						nPrcVen := 0
					
						//Busca Armazem do produto
						If AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SB1"
							SB1->(dbSetOrder(1))
		
							If SB1->(dbSeek(xFilial("SB1") + cProdPed)) 
						   		cArmPed := SB1->B1_LOCPAD						
							EndIf
						ElseIf AllTrim(SuperGetMv("MV_ARQPROD",, "SB1")) == "SBZ" 
							SBZ->(dbSetOrder(1))
								
							If SBZ->(dbSeek(xFilial("SBZ") + cProdPed))
						   		cArmPed := SBZ->BZ_LOCPAD
							EndIf										
						EndIf	
																					
						If cTipoPV == "4" //Transferencia Simbolica
							If AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "1" // Obtem preco - custo standard						
								nPrcVen := Posicione("SB1", 1, xFilial("SB1") + cProdPed, "B1_CUSTD")											
							ElseIf  AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "2" //Obtem preco - ultimo preco de compra						
								nPrcVen := Posicione("SB1", 1, xFilial("SB1") + cProdPed, "B1_UPRC")											
							ElseIf AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "3" //Obtem preco - custo medio unitario do armazem																																			 								
								nPrcVen := Posicione("SB2", 1, xFilial("SB2") + cProdPed + cArmPed, "B2_CM1")																				
							EndIf
								
							//Senao encontrou nenhum valor assume 1
							If nPrcVen == 0
								nPrcVen := 1
							EndIf
						Else
							nPrcVen := aSC6[nI, nY, 2] 
						EndIf
					Else
						nPrcVen := aSC6[nI, nY, 2]
					EndIf
					
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), nPrcVen, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_QTDLIB"
					If cTipoPV $ "3|4"
						nQtdLib := 0
						
						nPos := aScan(aSC6[nI], {|x| AllTrim(Upper(x[1])) == "C6_QTDVEN"})
						
						If nPos > 0
							nQtdLib  := aSC6[nI, nPos, 2]
						EndIf
					Else
						nQtdLib := aSC6[nI, nY, 2]
					EndIf
					
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), nQtdLib, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_VALOR"
					If cTipoPV == "4" //Transferencia Simbolica 
						//Busca Quantidade
						nPos := aScan(aSC6[nI], {|x| AllTrim(Upper(x[1])) == "C6_QTDVEN"})
						
						If nPos > 0
							nQtdLib  := aSC6[nI, nPos, 2]
						EndIf
																		
						If AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "1" // Obtem preco - custo standard						
							nPrcVen := Posicione("SB1", 1, xFilial("SB1") + cProdPed, "B1_CUSTD")											
						ElseIf  AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "2" //Obtem preco - ultimo preco de compra						
							nPrcVen := Posicione("SB1", 1, xFilial("SB1") + cProdPed, "B1_UPRC")											
						ElseIf AllTrim(SuperGetMv("MV_LJCUSVF",, "")) == "3" //Obtem preco - custo medio unitario do armazem
							nPos := aScan(aSC6[nI], {|x| AllTrim(Upper(x[1])) == "C6_LOCAL"})
							
							If nPos > 0									 
								nPrcVen := Posicione("SB2", 1, xFilial("SB2") + cProdPed + cArmPed, "B2_CM1")
							EndIf														
						EndIf
						
						//Senao encontrou nenhum valor assume 1
						If nPrcVen == 0
							nPrcVen := 1
						EndIf
																																	
						nPrcItem := nPrcVen * nQtdLib												
					Else
						nPrcItem := aSC6[nI, nY, 2]						
					EndIf
					
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), nPrcItem, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_DESCONT"
					If cTipoPV $ "3|4"  
						nPerDesc := 0						
					Else
						nPerDesc := aSC6[nI, nY, 2]						
					EndIf
					
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), nPerDesc, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_VALDESC"
					If cTipoPV $ "3|4" //Remessa por Conta e Ordem/Transferencia Simbolica 
						nValDesc := 0
					Else
						nValDesc := aSC6[nI, nY, 2]						
					EndIf
					
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), nValDesc, Nil})
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_PRUNIT"
					If cTipoPV $ "3|4" 
						aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), nPrcVen, Nil})
					Else
						aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), aSC6[nI, nY, 2], Nil})
					EndIf										
				Case AllTrim(aSC6[nI, nY, 1]) == "C6_LOCAL"
					If cTipoPV $ "3|4"					
						aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), cArmPed, Nil})
					Else
						aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), aSC6[nI, nY, 2], Nil})
					EndIf
				OtherWise
					aAdd(aLinhaPed, {AllTrim(aSC6[nI, nY, 1]), aSC6[nI, nY, 2], Nil})
			EndCase																													   	   									
		Next nY
		
		aAdd(aItensPed, aLinhaPed)
	Next nI

	//Efetiva a gravacao do Pedido de Vendas																				
	For nI := 1 To Len(aItensPed)
		RecLock("SC6", .T.)
		
		For nY := 1 To Len(aItensPed[nI])                 
			If SC6->(FieldPos(aItensPed[nI][nY][1]) > 0)
				SC6->(FieldPut(FieldPos(aItensPed[nI][nY][1]), aItensPed[nI][nY][2]))
			EndIf	
	 	Next nY
	 		
	 	SC6->(MsUnlock())		
	   
	   	FkCommit() // Commit para integridade referencial do SC6  
						
	   	RecLock("SC6", .F.)
		MaAvalSC6("SC6", 1, "SC5", lLiber, lTransf, @lLiberOk, @lResidOk, @lFaturOk,,,,,, lTLVReg)		
		SC6->(MsUnlock())	
		
		//Atualiza Preco de Venda no SC9 
   		If cTipoPV $ "3|4" //Remessa por Conta e Ordem/Transferencia Simbolica 
   			SC9->(dbSetOrder(2)) //C9_FILIAL+C9_CLIENTE+C9_LOJA+C9_PEDIDO+C9_ITEM
   		
   			If SC9->(dbSeek(SC6->C6_FILIAL + SC6->C6_CLI + SC6->C6_LOJA + SC6->C6_NUM + SC6->C6_ITEM))
   				RecLock("SC9",.F.)
   	        	SC9->C9_PRCVEN := SC6->C6_PRCVEN
				SC9->(MsUnlock())		
   			EndIf
   		EndIf 				                     				        			   	        						
	Next nI      
							
	MaAvalSC5("SC5", 1, lLiber, lTransf, @lLiberOk, @lResidOk, @lFaturOk,,,,,, .F.)
	SC5->(MsUnlock())
	
	//Verifica se houve erro na geracao do Pedido de Venda
	If lMsErroAuto
		lRet := .F.
	EndIf
EndIf

//Restaura filial
cFilAnt := cFilBkp

//Restaura a entrada da rotina                                    
RestArea(aAreaSC5)
RestArea(aAreaSC6)
RestArea(aAreaSC9)
RestArea(aAreaSF4)
RestArea(aArea)

Return Nil		

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7VlVFEPvºAutor³Vendas Clientes     º Data ³  21/10/14    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³ Valida se Pedidos de Venda VFE podem ser faturados.        º±± 
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ Lj7VlVFEPv( cOrcRes, cTpPv, aPvlNfs )					 		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³cOrcRes - Orcamento gerado no SIGALOJA.                		º±±
±±           ³cTpPv  - Tipo VFE do Pedido de Venda sendo gerado.         	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ lRet - Faturavel											       º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/

Function Lj7VlVFEPv(cOrcRes, cTpPv, aPvlNfs)

Local aArea     	:= GetArea()
Local aAreaSF1   	:= SF1->(GetArea())
Local lRet 		:= .T.
Local cWhere		:= ""
Local cItens		:= ""
Local cAliasTmp	:= GetNextAlias()
Local nI			:= 0

Default aPvlNfs := {}

//Armazena itens do Pedido de Venda
For nI := 1 To Len(aPvlNfs)
	cItens += "'" + aPvlNfs[nI][2] + "',"		
Next nI

If !Empty(cItens)
	cItens := Subs(cItens, 1, Len(cItens) - 1)
EndIf

//Condicional para a query		
cWhere := "% "
cWhere += " C5_ORCRES = " + "'" + cOrcRes + "'"

If cTpPv $ "4|5"
	cWhere += " AND C5_TPCD = '0'"
Else
	cWhere += " AND C5_TPCD IN ('2','4')"
EndIf

If !Empty(cItens)
	cWhere += " AND C6_ITEM IN (" + cItens + ")"
EndIf	
	
cWhere += " AND SC5.D_E_L_E_T_ = '' "   		   			
cWhere += " AND SC6.D_E_L_E_T_ = '' "
cWhere += " %"              											
                                          
//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		C5_NOTA, C5_SERIE, C5_TPCD, C6_NUM, C6_ITEM, C6_NOTA, C6_SERIE 
	FROM %table:SC5% SC5
	INNER JOIN %table:SC6% SC6	
	ON C5_FILIAL = C6_FILIAL AND C5_NUM = C6_NUM						
	WHERE %exp:cWhere%
	ORDER BY C5_TPCD 			
EndSql			

//Posiciona no inicio do arquivo temporario
(cAliasTmp)->(dbGoTop())

//Valida se pode faturar Pedido de Venda
If cTpPv == "2" //Remessa Entrega Futura 
	//Esse Pedido depende da Transferencia Simbolica
	While (cAliasTmp)->(!EOF())
		If (cAliasTmp)->C5_TPCD == "4" .And. Empty((cAliasTmp)->C6_NOTA) 
			lRet := .F.						
			Aviso(STR0011, STR0050 + " " + (cAliasTmp)->C6_NUM + ", " + STR0046 + "," + STR0051 + " " + (cAliasTmp)->C6_ITEM, {STR0047}) //"Atenção" #"Não foi possível faturar o Pedido:" ##"Antes é necessário faturar o Pedido: Transferência Simbólica" ###"Item:" ####"OK"									
			Exit	
		EndIf
			
		(cAliasTmp)->(dbSkip())	
	EndDo				
ElseIf cTpPv == "3" //Remessa por Conta e Ordem Showroom
	//Esse Pedido depende da Transferencia Simbolica e Remessa Entrega Futura
	While (cAliasTmp)->(!EOF())
		If Empty((cAliasTmp)->C6_NOTA) 
			lRet := .F.
			Aviso(STR0011, STR0050 + " " + (cAliasTmp)->C6_NUM + ", " + STR0045 + "," + STR0051 + " " + (cAliasTmp)->C6_ITEM, {STR0047}) //"Atenção" #"Não foi possível faturar o Pedido:" ##"Antes é necessário faturar os Pedidos: Transferência Simbólica e Remessa Entrega Futura" ###"Item:" ####"OK" 									
			Exit
		EndIf
			
		(cAliasTmp)->(dbSkip())	
	EndDo		
ElseIf cTpPv $ "4|5" //Transferencia Simbolica
	While (cAliasTmp)->(!EOF())
		If Empty((cAliasTmp)->C6_NOTA)
			lRet := .F.
			Aviso(STR0011, STR0050 + " " + (cAliasTmp)->C6_NUM + ", " + STR0052 + "," + STR0051 + " " + (cAliasTmp)->C6_ITEM, {STR0047}) //"Atenção" #"Não foi possível faturar o Pedido:" ##"Antes é necessário faturar o Pedido de Transferência no CDM" ###"Item:" ####"OK"  						
			Exit
		Else
			SF1->(dbSetOrder(1))
			
			If SF1->(dbSeek(xFilial("SF1") + (cAliasTmp)->C6_NOTA + (cAliasTmp)->C6_SERIE))
				If Empty(SF1->F1_STATUS)
					lRet := .F.
					Aviso(STR0011, STR0053 + " " + AllTrim((cAliasTmp)->C5_NOTA) + "/" + (cAliasTmp)->C5_SERIE + "," + STR0051 + " " + (cAliasTmp)->C6_ITEM, {STR0047}) //"Atenção" #"Antes é necessário efetuar a classificação do Documento de Entrada:" ##"Item:" ###"OK"										
					Exit
				EndIf
			Else
				lRet := .F.
				Aviso(STR0011, STR0054 + "," + STR0051 + " " + (cAliasTmp)->C6_ITEM, {STR0047}) //"Atenção" #"Não foi gerado Documento de Entrada para este movimento, verifique o Pedido de Transferência no CDM" ##"Item:" ###"OK"									
				Exit
			EndIf
		EndIf
	
		(cAliasTmp)->(dbSkip())		
	EndDo
EndIf

//Fecha Alias temporario
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf

//Restaura a entrada da rotina                                    
RestArea(aAreaSF1)
RestArea(aArea)

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7FilLoja ºAutor³Vendas Clientes     º Data ³  10/09/14    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Retorna a filial da Loja que efetuou a venda.               º±± 
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := Lj7FilLoja( cOrcRes ) 					              º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºParametros³ExpC1 - Orcamnto da Venda           		                  º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ cFilLoja  													    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Static Function Lj7FilLoja(cOrcRes)

Local cWhere 		:= ""
Local cFilLoja 	:= ""
Local cAliasTmp	:= GetNextAlias()

//Condicional para a query		
cWhere := "% "
cWhere += " C5_ORCRES = " + "'" + cOrcRes + "'"
cWhere += " AND C5_TPCD =  '1' "
cWhere += " AND SC5.D_E_L_E_T_ = '' "   		   			
cWhere += " %"              											
                                          
//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		C5_FILIAL, C5_NUM, C5_NOTA, C5_SERIE, C5_TPCD
	FROM %table:SC5% SC5						
		WHERE %exp:cWhere%				
EndSql

//Posiciona no inicio do arquivo temporario
(cAliasTmp)->(dbGoTop())

//Busca Filial da Loja
While (cAliasTmp)->(!EOF())	
	//Verifica se Pedido foi devolvido
	If !LojC090Dev((cAliasTmp)->C5_FILIAL, (cAliasTmp)->C5_NUM, (cAliasTmp)->C5_NOTA, (cAliasTmp)->C5_SERIE, (cAliasTmp)->C5_TPCD)
		cFilLoja := (cAliasTmp)->C5_FILIAL		
		Exit
	EndIf 
	
	(cAliasTmp)->(dbSkip())
EndDo

//Fecha Alias temporario
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf

Return cFilLoja	

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³Lj7VlCdLoc ºAutor³Vendas Clientes     º Data ³  06/08/15    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Valida se Codigo selecionado eh CD Local - CDL.             º±± 
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := Lj7VlCdLoc() 					              		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Logico    													    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/   

Function Lj7VlCdLoc()

Local aArea 	 := GetArea()
Local aAreaSLJ := SLJ->(GetArea())
Local lRet 	 := .T.

SLJ->(dbSetOrder(1))

//Nao valida quando campo vazio
If !Empty(&(__ReadVar))
	//Posiciona na Identificacao do CD Local
	If SLJ->(dbSeek(xFilial("SLJ") + &(__ReadVar)))
		If SLJ->LJ_TPCD <> "1"		
			lRet := .F.
			Alert(STR0055) //"CD Local a ser escolhido deve ser do Tipo CDL, verifique o Código correto de Identificação do CD Local desejado!"
		ElseIf M->LJ_ESTADO <> SLJ->LJ_ESTADO
			lRet := .F.
			Alert(STR0056) //"CD Local deve ser do mesmo Estado(UF) da Loja!"
		EndIf
	Else
		lRet := .F.
		Alert(STR0057) //"Código de Identificação do CD Local não encontrado!"		
	EndIf
EndIf

//Restaura a entrada da rotina                                    
RestArea(aAreaSLJ)
RestArea(aArea)

Return lRet

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7ExcVFE ºAutor³Vendas Clientes     º Data ³  07/08/15 	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Efetua a devolucao do Documento de Entrada quando Nota de   º±± 
±±           ³Saida de Transferencia Excluida.                            º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := LJ7ExcVFE() 					              		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil       													    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/  

Function LJ7ExcVFE(cSF2Doc, cSF2Serie)

Local aArea  	  := GetArea()
Local cWhere 	  := "" //Condicao da query
Local cNumNf	  := "" //Codigo da Nota de Devolucao
Local cItem	  := "00" //Item da Nota de Devolucao
Local cTesDoc	  := "" //Tes da Nota de Devolucao
Local cCfop	  := "" //CFOP da Nota de Devoluco
Local cFilBkp	  := cFilAnt //Backup da Filial
Local cAliasTmp := GetNextAlias() //Alias Temporario
Local cSerNf	  := SuperGetMv("MV_LJSERVF", Nil, "1") //Serie da NF VFE
Local nI		  := 0 //Contador
Local nY		  := 0 //Contador
Local aAreaSC5  := SC5->(GetArea())
Local aAreaSF1  := SF1->(GetArea())
Local aAreaSD1  := SD1->(GetArea()) 
Local aStruSF2  := SF2->(dbStruct())
Local aStruSD2  := SD2->(dbStruct())
Local aRegSD2	  := {}
Local aDocOri	  := {} 
Local aCabec	  := {}
Local aItens	  := {}      											                                          

Private lMSErroAuto	:= .F.	//VerIfica se ocorreu algum erro durante a Exclusao do Documento

//Condicional para a query		
cWhere := "% "
cWhere += " F1_FILORIG = " + "'" + xFilial("SF1") + "'"
cWhere += " AND F1_NFORIG = " + "'" + cSF2Doc + "'"
cWhere += " AND F1_SERORIG = " + "'" + cSF2Serie + "'"
cWhere += " AND SF1.D_E_L_E_T_ = '' "			
cWhere += " %"   

//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		F1_FILIAL, F1_DOC, F1_SERIE, F1_FORNECE, F1_LOJA
	FROM %table:SF1% SF1							
		WHERE %exp:cWhere%		   			
EndSql			

//Posiciona no inicio do arquivo temporario
(cAliasTmp)->(dbGoTop())
		
If (cAliasTmp)->(!EOF()) 		
	SF1->(dbSetOrder(1))		
		
	//Posiciona no Documento de Entrada
	SF1->(dbSeek((cAliasTmp)->F1_FILIAL + (cAliasTmp)->F1_DOC + (cAliasTmp)->F1_SERIE + (cAliasTmp)->F1_FORNECE + (cAliasTmp)->F1_LOJA))		
	
	SC5->(dbSetOrder(1))
	
	//Posiciona no Pedido de Venda Origem (Transferencia ou Transferencia Simbolica)
	If SC5->(dbSeek(SF1->F1_FILPV + SF1->F1_NUMPV)) .And. SC5->C5_TPCD $ "0|4"																																													
		//Se Documento nao esta classificado, apenas deleta informacoes
		If Empty(SF1->F1_STATUS)
			aCabec := {}
			aItens := {}
			
			//Armazena Cabecalho do Documento
			aAdd(aCabec, {"F1_FILIAL"	, SF1->F1_FILIAL})
			aAdd(aCabec, {"F1_DOC"		, SF1->F1_DOC})
			aAdd(aCabec, {"F1_SERIE"    , SF1->F1_SERIE})
			aAdd(aCabec, {"F1_FORNECE"  , SF1->F1_FORNECE})
			aAdd(aCabec, {"F1_LOJA"		, SF1->F1_LOJA})				
			
			SD1->(dbSetOrder(1))
			
			If SD1->(dbSeek(SF1->F1_FILIAL + SF1->F1_DOC + SF1->F1_SERIE + SF1->F1_FORNECE + SF1->F1_LOJA))
				While SD1->(!EOF()) .And. SD1->D1_FILIAL == SF1->F1_FILIAL .And. SD1->D1_DOC == SF1->F1_DOC .And.; 
					SD1->D1_SERIE == SF1->F1_SERIE .And. SD1->D1_FORNECE == SF1->F1_FORNECE .And.;
					SD1->D1_LOJA == SF1->F1_LOJA
					
					//Armazena Itens do Documento de Entrada
					aLinha := {}
					
					aAdd(aLinha, {"D1_FILIAL"	, SD1->D1_FILIAL	, Nil})
					aAdd(aLinha, {"D1_DOC"		, SD1->D1_DOC		, Nil})
					aAdd(aLinha, {"D1_SERIE"		, SD1->D1_SERIE	, Nil})
					aAdd(aLinha, {"D1_FORNECE"	, SD1->D1_FORNECE	, Nil})
					aAdd(aLinha, {"D1_LOJA"		, SD1->D1_LOJA	, Nil})						
					aAdd(aItens, aLinha)
					  												
					SD1->(dbSkip())
				EndDo
			EndIf									
			
			//Altera Filial 
			cFilAnt := SF1->F1_FILIAL
			
			lMsErroAuto := .F.
			
			//Exclui Documento de Entrada
			MATA140(aCabec, aItens, 5)
			
			//Exibe Erros na Exclusao do Documento
			If lMsErroAuto      
				MostraErro()					 												
			EndIf
			
			//Restaura a Filial original
			cFilAnt := cFilBkp
		Else //Gera Documento de Devolucao do Documento de Entrada				
			//Altera Filial para geracao da Nota de Devolucao
			cFilAnt := SF1->F1_FILIAL
			
			//Adiciona Cabecalho da NF de Devolucao	
			For nI := 1 To Len(aStruSF2)
				Do Case
					Case AllTrim(aStruSF2[nI][1]) == "F2_FILIAL"						
						aAdd(aCabec, SF1->F1_FILIAL)
					Case AllTrim(aStruSF2[nI][1]) == "F2_SERIE"
						aAdd(aCabec, cSerNf)
					Case AllTrim(aStruSF2[nI][1]) == "F2_CLIENTE"
						aAdd(aCabec, SF1->F1_FORNECE)
					Case AllTrim(aStruSF2[nI][1]) == "F2_LOJA"
						aAdd(aCabec, SF1->F1_LOJA)
					Case AllTrim(aStruSF2[nI][1]) == "F2_TIPO"
						aAdd(aCabec, "D")
					Case AllTrim(aStruSF2[nI][1]) == "F2_EMISSAO"
						aAdd(aCabec, dDataBase)
					Case AllTrim(aStruSF2[nI][1]) == "F2_EST"
						aAdd(aCabec, SF1->F1_EST)
					Case AllTrim(aStruSF2[nI][1]) == "F2_ESPECIE"
						aAdd(aCabec, SF1->F1_ESPECIE)
					Case AllTrim(aStruSF2[nI][1]) == "F2_VALMERC"
						aAdd(aCabec, SF1->F1_VALMERC)
					Case AllTrim(aStruSF2[nI][1]) == "F2_VALBRUT"
						aAdd(aCabec, SF1->F1_VALBRUT)						
					Case AllTrim(aStruSF2[nI][1]) == "F2_BASEICM"
						aAdd(aCabec, SF1->F1_BASEICM)						
					Case AllTrim(aStruSF2[nI][1]) == "F2_BASEIPI"
						aAdd(aCabec, SF1->F1_BASEIPI)
					Case AllTrim(aStruSF2[nI][1]) == "F2_COND"
						aAdd(aCabec, SF1->F1_COND)
					Case AllTrim(aStruSF2[nI][1]) == "F2_NFORI"
						aAdd(aCabec, SF1->F1_DOC)
					Case AllTrim(aStruSF2[nI][1]) == "F2_SERIORI"
						aAdd(aCabec, SF1->F1_SERIE)					
					OtherWise
						If aStruSF2[nI][2] $ "C/M"	
							aAdd(aCabec, "")
						ElseIf aStruSF2[nI][2] == "D"	
							aAdd(aCabec, CToD(""))
						ElseIf aStruSF2[nI][2] == "N"	
							aAdd(aCabec, 0)
						ElseIf aStruSF2[nI][2] == "L"	
							aAdd(aCabec, .F.)
						EndIf
				EndCase
			Next nI
			
			SD1->(dbSetOrder(1))
			
			If SD1->(dbSeek(SF1->F1_FILIAL + SF1->F1_DOC + SF1->F1_SERIE + SF1->F1_FORNECE + SF1->F1_LOJA))
				While SD1->(!EOF()) .And. SD1->D1_FILIAL == SF1->F1_FILIAL .And. SD1->D1_DOC == SF1->F1_DOC .And.; 
					SD1->D1_SERIE == SF1->F1_SERIE .And. SD1->D1_FORNECE == SF1->F1_FORNECE .And.;
					SD1->D1_LOJA == SF1->F1_LOJA												
					
					SF4->(dbSetOrder(1))
					
					If SF4->(dbSeek(xFilial("SF4") + SD1->D1_TES)) 
						cTesDoc := SF4->F4_TESDV
	
						//Posiciona na TES de Devolucao para pegar CFOP
						If SF4->(dbSeek(xFilial("SF4") + cTesDoc))
							cCfop := SF4->F4_CF
						EndIf
					EndIf												
					  
					aAdd(aDocOri, 0)
					aAdd(aItens, {})					
					nY ++
					cItem := Soma1(cItem)					
																																																																	
					//Adiciona itens da NF
					For nI := 1 To Len(aStruSD2)																										
						Do Case
							Case AllTrim(aStruSD2[nI][1]) == "D2_FILIAL"																
								aAdd(aItens[nY], SD1->D1_FILIAL)
							Case AllTrim(aStruSD2[nI][1]) == "D2_ITEM"
								aAdd(aItens[nY], cItem)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_QUANT"
								aAdd(aItens[nY], SD1->D1_QUANT)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_COD"
								aAdd(aItens[nY], SD1->D1_COD)
							Case AllTrim(aStruSD2[nI][1]) == "D2_LOCAL"
								aAdd(aItens[nY], SD1->D1_LOCAL)	
							Case AllTrim(aStruSD2[nI][1]) == "D2_UM"
								aAdd(aItens[nY], SD1->D1_UM)																					
							Case AllTrim(aStruSD2[nI][1]) == "D2_PRCVEN"
								aAdd(aItens[nY], SD1->D1_VUNIT)	
							Case AllTrim(aStruSD2[nI][1]) == "D2_DESC"
								aAdd(aItens[nY], SD1->D1_VALDESC)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_TOTAL"
								aAdd(aItens[nY], SD1->D1_TOTAL)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_TES"
								aAdd(aItens[nY], cTesDoc)
							Case AllTrim(aStruSD2[nI][1]) == "D2_CF"
								aAdd(aItens[nY], cCfop)																							
							Case AllTrim(aStruSD2[nI][1]) == "D2_PICM"
								aAdd(aItens[nY], SD1->D1_PICM)	
							Case AllTrim(aStruSD2[nI][1]) == "D2_IPI"
								aAdd(aItens[nY], SD1->D1_IPI)																						
							Case AllTrim(aStruSD2[nI][1]) == "D2_TIPO"
								aAdd(aItens[nY], "D")		
							Case AllTrim(aStruSD2[nI][1]) == "D2_CLIENTE"
								aAdd(aItens[nY], SD1->D1_FORNECE)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_LOJA"
								aAdd(aItens[nY], SD1->D1_LOJA)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_QTDEDEV"
								aAdd(aItens[nY], SD1->D1_QUANT)								
							Case AllTrim(aStruSD2[nI][1]) == "D2_VALDEV"
								aAdd(aItens[nY], SD1->D1_TOTAL)									
							Case AllTrim(aStruSD2[nI][1]) == "D2_BASEICM"
								aAdd(aItens[nY], SD1->D1_BASEICM)									
							Case AllTrim(aStruSD2[nI][1]) == "D2_EMISSAO"
								aAdd(aItens[nY], dDataBase)									
							Case AllTrim(aStruSD2[nI][1]) == "D2_NFORI"
								aAdd(aItens[nY], SD1->D1_DOC)	
							Case AllTrim(aStruSD2[nI][1]) == "D2_SERIORI"
								aAdd(aItens[nY], SD1->D1_SERIE)																													
							OtherWise
								If aStruSD2[nI][2] $ "C/M"	
									aAdd(aItens[nY], "")
								ElseIf aStruSD2[nI][2] == "D"	
									aAdd(aItens[nY], CToD(""))
								ElseIf aStruSD2[nI][2] == "N"	
									aAdd(aItens[nY], 0)
								ElseIf aStruSD2[nI][2] == "L"	
									aAdd(aItens[nY], .T.)			
								EndIf								
						EndCase																			
					Next nI				
					
					SD1->(dbSkip())
				EndDo
			EndIf	
											
			//Inclusao da NF de Devolucao                                                      				
			cNumNf := MaNfs2Nfs(,, SC5->C5_CLIENTE, SC5->C5_LOJACLI,; 
										cSerNf,,,,,,,,,,,,{|| aRegSD2}, {||}, aDocOri, aItens, aCabec,	.T.,  {|| .T.},  {|| .T.}, {|| .T.})
		
			//Restaura a Filial original
			cFilAnt := cFilBkp
		EndIf
		
		//Exclui Pedidos de Vendas VFE
		LJ7ExcPed(SC5->C5_ORCRES)																
	EndIf
EndIf
		
//Fecha Alias temporario
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf		

//Restaura a entrada da rotina                                    
RestArea(aAreaSC5)
RestArea(aAreaSF1)
RestArea(aAreaSD1)
RestArea(aArea)

Return Nil

/*
ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
±±ÉÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍËÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍ»±±
±±ºPrograma  ³LJ7ExcPed ºAutor³Vendas Clientes     º Data ³  08/08/15 	º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÊÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºDesc.     ³Efetua a exclusao dos Pedidos de Venda quando Documento VFE º±± 
±±           ³Devolvido ou Excluido.                                      º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºSintaxe   ³ExpA1 := LJ7ExcPed() 					              		º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºRetorno   ³ Nil       													    º±±
±±ÌÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¹±±
±±ºUso       ³ SigaLoja/FrontLoja                                         º±±
±±ÈÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼±±
±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±
ßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßßß
*/  

Function LJ7ExcPed(cOrcRes)

Local aArea		:= GetArea()
Local aAreaAux	:= {} //Auxiliar para armazenar areas durante as execucoes
Local aAreaSC5	:= SC5->(GetArea())
Local aAreaSC6	:= SC6->(GetArea())
Local aAreaSC9	:= SC9->(GetArea())
Local cWhere	:= "" //Condicao da query
Local cFilBkp	:= cFilAnt //Backup da Filial
Local cAliasTmp	:= GetNextAlias() //Alias Temporario
Local aCabec	:= {} //Cabecalho do Pedido de Venda
Local aItens	:= {} //Itens do Pedido de Venda

Private lMSErroAuto	:= .F.	//VerIfica se ocorreu algum erro durante a Exclusao do PV

//Apaga os Pedidos de Vendas VFE que restaram	
cWhere := "% "
cWhere += " C5_ORCRES = " + "'" + cOrcRes + "'"
cWhere += " AND C5_NOTA = ''"
cWhere += " AND C5_SERIE = ''"
cWhere += " AND C5_TPCD <> ''"
cWhere += " AND SC5.D_E_L_E_T_ = ''"			
cWhere += " %"
			
//Executa a query
BeginSql alias cAliasTmp
	SELECT 
		C5_FILIAL, C5_NUM 		
	FROM %table:SC5% SC5							
		WHERE %exp:cWhere%		   			
EndSql	
			
//Posiciona no inicio do arquivo temporario
(cAliasTmp)->(dbGoTop()) 
SC5->(dbSetOrder(1)) //C5_FILIAL+C5_NUM
SC6->(dbSetOrder(1)) //C6_FILIAL+C6_NUM+C6_ITEM+C6_PRODUTO
SC9->(dbSetOrder(1)) //C9_FILIAL+C9_PEDIDO
//Busca Pedidos de Venda do Orcamento
While (cAliasTmp)->(!EOF())	
	//Posiciona no Pedido de Venda gerado por VFE
	If SC5->(dbSeek((cAliasTmp)->C5_FILIAL + (cAliasTmp)->C5_NUM))	
		//Elimina residuo de Itens e atualiza Cabecalho do Pedido de Venda										 					
		cFilAnt := (cAliasTmp)->C5_FILIAL //Altera para a filial do Pedido de Venda
		//Estorna Liberacao
		If SC9->(dbSeek((cAliasTmp)->C5_FILIAL + (cAliasTmp)->C5_NUM))
			While SC9->(!Eof()) .And. SC9->C9_FILIAL + SC9->C9_PEDIDO == (cAliasTmp)->C5_FILIAL + (cAliasTmp)->C5_NUM 
				aAreaAux := GetArea() //Salva area
				a460Estorna() //Executa estorno liberacao
				RestArea(aAreaAux) //Restaura area
				SC9->(dbSkip())
			EndDo
		EndIf
		//Posiciona nos Itens do Pedido de Venda
		If SC6->(dbSeek((cAliasTmp)->C5_FILIAL + (cAliasTmp)->C5_NUM))
			While SC6->(!Eof()) .And. SC6->C6_FILIAL + SC6->C6_NUM == (cAliasTmp)->C5_FILIAL + (cAliasTmp)->C5_NUM		
				aAreaAux := GetArea() //Salva area
				MaResDoFat(Nil, .T., .F., Nil) //Efetua estorno Itens
				RestArea(aAreaAux) //Retaura area
				SC6->(dbSkip())
			EndDo
			aAreaAux := GetArea() //Salva area
			MaLiberOk({(cAliasTmp)->C5_NUM}, .T.) //Efetua estorno Cabecalho
		 	RestArea(aAreaAux) //Restaura area  
		EndIf
		
		//Se o Pedido de Venda VFE nao estava classificado, nao ocorrera estorno e para este caso sera excluido
		If Empty(SC5->C5_NOTA)
			aCabec := {} //Inicializa Cabecalho
			aItens := {} //Inicializa Itens
			//Armazena Cabecalho do Pedido de Venda
			aAdd(aCabec, {"C5_FILIAL"	, (cAliasTmp)->C5_FILIAL 	, Nil})
			aAdd(aCabec, {"C5_NUM"		, (cAliasTmp)->C5_NUM 		, Nil})	
			//Busca Itens do Pedido de Venda
			If SC6->(dbSeek((cAliasTmp)->C5_FILIAL + (cAliasTmp)->C5_NUM))
				While SC6->(!EOF()) .And. SC6->C6_FILIAL == (cAliasTmp)->C5_FILIAL .And. SC6->C6_NUM == (cAliasTmp)->C5_NUM 
					aLinha := {}
					//Armazena Itens do Pedido de Venda			
					aAdd(aLinha, {"C6_FILIAL"	, SC6->C6_FILIAL	, Nil})
					aAdd(aLinha, {"C6_NUM"		, SC6->C6_NUM		, Nil})
					aAdd(aLinha, {"C6_ITEM"		, SC6->C6_ITEM,	, Nil})
					aAdd(aLinha, {"C6_PRODUTO"	, SC6->C6_PRODUTO	, Nil})			
					aAdd(aItens, aLinha)
					//Libera Empenho
					SC6->(RecLock("SC6"), .F.)
					SC6->C6_QTDEMP := 0
					SC6->(MsUnLock())
					SC6->(dbSkip())
				EndDo
			EndIf	
							
			lMSErroAuto := .F.
			//Exclui Pedido de Venda
			MATA410(aCabec, aItens, 5)
			//Exibe Erros na Exclusao do PV
			If lMsErroAuto      
				MostraErro()					 												
			EndIf	
		EndIf
	EndIf
	(cAliasTmp)->(dbSkip())
EndDo
//Fecha arquivo temporario			
If (Select(cAliasTmp) > 0)
	(cAliasTmp)->(dbCloseArea())
EndIf

//Retorna filial
cFilAnt := cFilBkp
//Restaura a entrada da rotina                                    
RestArea(aAreaSC5)
RestArea(aAreaSC6)
RestArea(aAreaSC9)
RestArea(aArea)
Return Nil