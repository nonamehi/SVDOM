/************************************************************************* 
 > File Name   : svdom_cfg_node.sv
 > Author      : liujiaqi
 > Created Time: Friday May 30 15:48:39 2025
 ************************************************************************/
`ifndef SVDOM_CFG_NODE__SV
 `define SVDOM_CFG_NODE__SV
typedef bit[`SVDOM_MAX_DATA_WIDTH-1:0] TYPE_SVDOM_CFG_DOM_WIDTH;
typedef class Csvdom_cfg_node;
virtual class Csvdom_cfg_node_listener extends uvm_object;

   function new(string name = "Csvdom_cfg_node_listener",uvm_object parent = null);
      super.new(name,parent);
   endfunction // new

   pure virtual function void ListenerF(Csvdom_cfg_node cfg_node);
endclass // Csvdom_cfg_node_listener

class Csvdom_cfg_node_listener_file extends Csvdom_cfg_node_listener;
   string nodeStrQ[$];
   
   function new(string name = "Csvdom_cfg_node_listener_file",uvm_object parent = null);
      super.new(name,parent);
   endfunction // new
   
   virtual function void ListenerF(Csvdom_cfg_node cfg_node);
      if (cfg_node.attributeList.size()) nodeStrQ.push_back({"[",cfg_node.get_full_name(),"]"});
      foreach (cfg_node.attributeList[index])begin
         nodeStrQ.push_back({index,"=",cfg_node.attributeList[index]});
      end
   endfunction // ListenerF

   virtual function void Cat2FileF(input string iFileName,input string iType="w");
      integer  fileHandler;
      fileHandler = $fopen(iFileName,iType);
      foreach (nodeStrQ[index]) begin
         $fwrite(fileHandler,"%s\n",nodeStrQ[index]);
      end
      $fclose(fileHandler);
   endfunction // Cat2FileF
   
endclass // Csvdom_cfg_node_listener_file

class Csvdom_cfg_node extends uvm_object;
   local Csvdom_cfg_node _parent;
   local Csvdom_cfg_node childNode[string];
   string  attributeList[string];
   local bit attributeIsUsed[string];
   
   function new(string name = "Csvdom_cfg_node",uvm_object parent = null);
      super.new(name,parent);
   endfunction // new

   function void PrintNodeF();
      $display("======%s",get_full_name());
      foreach (attributeList[index]) begin
         $display("=== %s:%s,isused %0d",index,attributeList[index],attributeIsUsed[index]);
      end
      foreach (childNode[index]) childNode[index].PrintNodeF();
   endfunction // PrintNodeF
   
   function void ListenerF(Csvdom_cfg_node_listener cfg_node_listener);
      if (get_full_name() != "") begin
         cfg_node_listener.ListenerF(this);
      end
      foreach (childNode[index]) begin
         childNode[index].ListenerF(cfg_node_listener);
      end
   endfunction // ListenerF
   
   function bit AttributeNotAllUsedCheckF(input bit iCheckEna=1);
      foreach (childNode[index]) begin
         if (childNode[index].AttributeNotAllUsedCheckF(iCheckEna)) return 1;
      end
     AttributeNotAllUsedCheckF = attributeIsUsed.sum() with (TYPE_SVDOM_CFG_DOM_WIDTH'(item)) != attributeIsUsed.size();
      if (AttributeNotAllUsedCheckF && iCheckEna) begin
         PrintNodeF();
         `UVM_FATAL(get_full_name(),"AttributeNotAllUsedCheckF");
      end
   endfunction // AttributeNotAllUsedCheckF
      
   function TYPE_SVDOM_CFG_DOM_WIDTH ConvertStr2IntF(input string iString);
      string resultQ[$];
      resultQ = svlib_pkg::regex_split(iString,"^\\s*(0[x|X|b|B])*(\\S+)\\s*$");
      case (resultQ[1])
        ""   : return resultQ[2].atoi();
        "0x" : return resultQ[2].atohex();
        "0X" : return resultQ[2].atohex();
        "0b" : return resultQ[2].atobin();
        "0B" : return resultQ[2].atobin();
        default : begin
           `UVM_FATAL("",$sformatf("default %s %s don't match int type",iString,resultQ[1]));
        end
      endcase // case (resultQ[1])
   endfunction // ConvertStr2IntF

  function string ConvertInt2StrF(input TYPE_SVDOM_CFG_DOM_WIDTH iData);
      ConvertInt2StrF.hextoa(iData);
      return {"0x",ConvertInt2StrF};
   endfunction // ConvertInt2StrF
   
   function Csvdom_cfg_node GetNodeByNameF(input string iNodeName,input bit iCheckEna=1);
      if ((iNodeName == "-") || (iNodeName == "")) return this;
      return __GetNodeByNameQF(svlib_pkg::str_split(iNodeName,"."),iNodeName,iCheckEna);
   endfunction

   protected function Csvdom_cfg_node __GetNodeByNameQF(input string iNondeNameQ[$],input string iNodeName,input bit iCheckEna=1);
      if(iNondeNameQ.size()) begin
         string nodeName;
         nodeName = iNondeNameQ.pop_front();
         if (!childNode.exists(nodeName)) childNode[nodeName] = new(nodeName,this);
         return childNode[nodeName].__GetNodeByNameQF(iNondeNameQ,iNodeName);
      end else begin
         return this;
      end
      if (iCheckEna) begin
         `UVM_FATAL("",$sformatf("can't find nodename : %s",iNodeName));
      end
   endfunction // __GetNodeByNameQF
   
   function void AddAttributeF(input string iAttributeName,iValue,input bit iIsUsed=0);
      this.attributeList[iAttributeName] = iValue;
      this.attributeIsUsed[iAttributeName] = iIsUsed;
   endfunction // AddAttribute

   function void AddAttributeIntF(input string iAttributeName,input TYPE_SVDOM_CFG_DOM_WIDTH iValue,input bit iIsUsed=0);
      AddAttributeF(iAttributeName,ConvertInt2StrF(iValue),iIsUsed);
   endfunction // AddAttributeIntF

   function void AddAttributeStringF(input string iAttributeName,iValue,input bit iIsUsed=0);
      AddAttributeF(iAttributeName,iValue,iIsUsed);
   endfunction // AddAttributeStringF
      
   function string GetAttributeF(input string iAttributeName,input bit iCheckEna=1);
      if (this.attributeList.exists(iAttributeName)) begin
         this.attributeIsUsed[iAttributeName] = 1;
         return this.attributeList[iAttributeName];
      end
      if (iCheckEna) begin
         `UVM_FATAL("",$sformatf("can't find attribute : %s in %s",iAttributeName,get_full_name()));
      end else begin
         return "";
      end
   endfunction // GetAttributeF

   function bit CheckAttributeExists(input string iAttributeName);
      return GetAttributeF(iAttributeName,0) != "";
   endfunction // CheckAttributeExists
   
   function TYPE_SVDOM_CFG_DOM_WIDTH GetAttributeIntF(input string iAttributeName,input TYPE_SVDOM_CFG_DOM_WIDTH iValue=-1,input bit iCheckEna=1);
      GetAttributeIntF = iValue;
      if(uvm_config_db #(int)::get(null,get_full_name(),iAttributeName,GetAttributeIntF)) begin
         AddAttributeIntF(iAttributeName,GetAttributeIntF,1);
         return GetAttributeIntF;
      end
      begin
         string attributeName;
         attributeName = GetAttributeF(iAttributeName,iCheckEna);
         if (attributeName != "") begin
            GetAttributeIntF = ConvertStr2IntF(attributeName);
         end
      end
   endfunction // GetAttributeIntF
   
   function string GetAttributeStringF(input string iAttributeName,input string iValue="",input bit iCheckEna=1);
      GetAttributeStringF = iValue;
      if(uvm_config_db #(string)::get(null,get_full_name(),iAttributeName,GetAttributeStringF)) begin
         AddAttributeStringF(iAttributeName,GetAttributeStringF,1);
         return GetAttributeStringF;
      end
      begin
         string attributeName;
         attributeName = GetAttributeF(iAttributeName,iCheckEna);
         if (attributeName != "") begin
            GetAttributeStringF = attributeName;
         end
      end
   endfunction // GetAttributeStringF
      
endclass // Csvdom_cfg_node
`endif
