#############################################################################
##
##                                                           AutoDoc package
##
##  Copyright 2013, Sebastian Gutsche, TU Kaiserslautern
##
#############################################################################

##
InstallGlobalFunction( AutoDoc_RemoveSpacesAndComments,
                       
  function( string )
    
    while string <> "" and ( string[ 1 ] = ' ' or string[ 1 ] = '#' ) do
        
        Remove( string, 1 );
        
    od;
    
    while string <> "" and string[ Length( string ) ] = ' ' do
        
        Remove( string, Length( string ) );
        
    od;
    
    return string;
    
end );

##
InstallGlobalFunction( AutoDoc_Scan_for_command,
                       
  function( string )
    local command_pos, rest_of_string, i , command_list;
    
    command_pos := PositionSublist( string, "@" );
    
    if command_pos = fail then
        
        return [ false, AutoDoc_RemoveSpacesAndComments( string ) ];
        
    fi;
    
    string := string{ [ command_pos .. Length( string ) ] };
    
    command_list := [ "@AutoDoc",
                      "@EndAutoDoc",
                      "@Chapter",
                      "@Section",
                      "@EndSection",
                      "@BeginGroup",
                      "@EndGroup",
                      "@Description",
                      "@ReturnValue",
                      "@Arguments",
                      "@Group",
                      "@Label",
                      "@FunctionLabel" ];
                      
    for i in command_list do
        
        command_pos := PositionSublist( string, i );
        
        if command_pos <> fail then
            
            return [ i, AutoDoc_RemoveSpacesAndComments( string{[ command_pos + Length( i ) .. Length( string ) ] } ) ];
            
        fi;
        
    od;
    
    return;
    
end );

##
InstallGlobalFunction( AutoDoc_Flush,
                       
  function( current_item )
    local type;
    
    type := current_item[ 1 ];
    
    if type = "Chapter" then
        
        Add( AUTOMATIC_DOCUMENTATION.tree, DocumentationText( current_item[ 3 ], [ current_item[ 2 ] ] ) );
        
    elif type = "Section" then
        
        Add( AUTOMATIC_DOCUMENTATION.tree, DocumentationText( current_item[ 4 ], [ current_item[ 2 ], current_item[ 3 ] ] ) );
        
    elif type = "Item" then
        
        Add( AUTOMATIC_DOCUMENTATION.tree, DocumentationItem( current_item[ 2 ] ) );
        
    fi;
    
end );

##
InstallGlobalFunction( AutoDoc_Prepare_Item_Record,
                       
  function( current_item, chapter_info )
    local type;
    
    type := current_item[ 1 ];
    
    if type = "Chapter" or type = "Section" then
        
        AutoDoc_Flush( current_item );
        
        current_item := [ "Item", rec( ) ];
        
    fi;
    
    if IsBound( chapter_info[ 1 ] ) and IsBound( chapter_info[ 2 ] ) then
        
        current_item[ 2 ].chapter_info := chapter_info;
        
    fi;
    
    return current_item;
    
end );

##
InstallGlobalFunction( AutoDoc_Type_Of_Item,
                       
  function( current_item, type )
    local item_rec, entries, has_filters;
    
    item_rec := current_item[ 2 ];
    
    if type = "Category" then
        
        entries := [ "Filt", "categories" ];
        
        has_filters := "One";
        
    elif type = "Representation" then
        
        entries := [ "Filt", "categories" ];
        
        has_filters := "One";
        
    elif type = "Attribute" then
        
        entries := [ "Attr", "attributes" ];
        
        has_filters := "One";
        
    elif type = "Property" then
        
        entries := [ "Prop", "properties" ];
        
        has_filters := "One";
        
    elif type = "Operation" then
        
        entries := [ "Oper", "operations" ];
        
        has_filters := "List";
        
    elif type = "GlobalFunction" then
        
        entries := [ "Func", "global_functions" ];
        
        has_filters := "No";
        
    elif type = "GlobalVariable" then
        
        entries := [ "Var", "global_variables" ];
        
        has_filters := "No";
        
    else
        
        return fail;
        
    fi;
    
    item_rec.type := entries[ 1 ];
    
    item_rec.doc_type := entries[ 2 ];
    
    return has_filters;
    
end );

##
InstallGlobalFunction( AutoDoc_Parser_ReadFile,
                       
  function( filename )
    local warning_class, filestream, autodoc_active, current_line,
          chapter_info, is_autodoc_comment, is_function_declaration,
          pos_of_autodoc_comment, declare_position, current_item,
          has_filters, filter_string, current_command, current_string_list,
          scope_chapter, scope_section, scope_group, current_type;
    
    warning_class := NewInfoClass( "warning_class" );
    
    SetInfoLevel( warning_class, 1 );
    
    filestream := InputTextFile( filename );
    
    ## After this, I assume the stream contains one line.
    if filestream = fail then
        
        Info( warning_class, 1, "Warning: The text file ", filename, " was not readable.\n" );
        
        return;
        
    fi;
    
    autodoc_active := false;
    
    chapter_info := [ ];
    
    ## Next if ensures termination.
    while true do
        
        current_line := ReadLine( filestream );
        
        ## Ensures termination of the loop.
        if current_line = fail then
            
            AutoDoc_Flush( current_item );
            
            break;
            
        fi;
        
        NormalizeWhitespace( current_line );
        
        if current_line = "" then
            
            continue;
            
        fi;
        
        is_autodoc_comment := false;
        
        is_function_declaration := false;
        
        pos_of_autodoc_comment := PositionSublist( current_line, "#!" );
        
        ## Check wether line contains autodoc comments
        if pos_of_autodoc_comment  <> fail then
          
          current_line := current_line{[ pos_of_autodoc_comment + 2 .. Length( current_line ) ]};
          
          current_line := AutoDoc_RemoveSpacesAndComments( current_line );
          
          is_autodoc_comment := true;
          
          is_function_declaration := false;
          
        fi;
        
        ## Assures no function will be read while AutoDoc is not active
        if not autodoc_active and not is_autodoc_comment then
            
            continue;
            
        fi;
        
        if autodoc_active and not is_autodoc_comment then
            
            ## Scan if it is the beginning of a declaration.
            declare_position := PositionSublist( current_line, "Declare" );
            
            if declare_position = fail then
                
                continue;
                
            fi;
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_line := current_line{[ declare_position + 7 .. Length( current_line ) ]};
            
            if PositionSublist( current_line, "(" ) = fail then
                
                Error( "Something went wrong" );
                
            fi;
            
            current_type := current_line{ [ 1 .. PositionSublist( current_line, "(" ) - 1 ] };
            
            has_filters := AutoDoc_Type_Of_Item( current_item, current_type );
            
            current_line := current_line{ [ PositionSublist( current_line, "(" ) + 1 .. Length( current_line ) ] };
            
            ## Not the funny part begins:
            ## try fetching the name:
            
            ## Assuming the name is in the same line as its 
            while PositionSublist( current_line, "," ) = fail do
                
                current_line := ReadLine( filestream );
                
            od;
            
            NormalizeWhitespace( current_line );
            
            current_line := AutoDoc_RemoveSpacesAndComments( current_line );
            
            current_item[ 2 ].name := current_line{ [ 1 .. PositionSublist( current_line, "," ) - 1 ] };
            
            current_item[ 2 ].name := AutoDoc_RemoveSpacesAndComments( ReplacedString( current_item[ 2 ].name, "\"", "" ) );
            
            current_line := current_line{ [ PositionSublist( current_line, "," ) + 1 .. Length( current_line ) ] };
            
            Error( "test0" );
            
            if has_filters = "One" then
                
                filter_string := "for ";
                
                while PositionSublist( current_line, "," ) = fail do
                    
                    Append( filter_string, AutoDoc_RemoveSpacesAndComments( current_line ) );
                    
                    current_line := ReadLine( filestream );
                    
                    NormalizeWhitespace( current_line );
                    
                od;
                
                Append( filter_string, AutoDoc_RemoveSpacesAndComments( current_line{ [ 1 .. PositionSublist( current_line, "," ) - 1 ] } ) );
                
            elif has_filters = "List" then
                
                filter_string := "for ";
                
                
                Error( "test" );
                
                while PositionSublist( current_line, "[" ) = fail do
                    
                    current_line := ReadLine( filestream );
                    
                    NormalizeWhitespace( current_line );
                    
                od;
                
                current_line := current_line{ [ PositionSublist( current_line, "[" ) + 1 .. Length( current_line ) ] };
                
                Error( "test2" );
                
                while PositionSublist( current_line, "]" ) = fail do
                    
                    Append( filter_string, AutoDoc_RemoveSpacesAndComments( current_line ) );
                    
                    current_line := ReadLine( filestream );
                    
                    NormalizeWhitespace( current_line );
                    
                od;
                
                Error( "test3" );
                
                Append( filter_string, AutoDoc_RemoveSpacesAndComments( current_line{[ 1 .. PositionSublist( current_line, "]" ) - 1 ]} ) );
                
                Error( "test4" );
                
            else
                
                filter_string := false;
                
            fi;
            
            current_item[ 2 ].list_of_filters := filter_string;
            
            ## Everything is done now.
            
            AutoDoc_Flush( current_item );
            
            continue;
            
        fi;
        
        current_command := AutoDoc_Scan_for_command( current_line );
        
        if current_command[ 1 ] = false then
            
            Add( current_string_list, current_command[ 2 ] );
            
            continue;
            
        fi;
        
        ## Go through commands
        if current_command[ 1 ] = "@AutoDoc" then
            
            autodoc_active := true;
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@Chapter" then
            
            ## First chapter has no current item.
            if IsBound( current_item ) then AutoDoc_Flush( current_item ); fi;
            
            ## Reset section
            Unbind( scope_section );
            
            scope_chapter := ReplacedString( current_command[ 2 ], " ", "_" );
            
            current_item := [ "Chapter", scope_chapter, [ ] ];
            
            ChapterInTree( AUTOMATIC_DOCUMENTATION.tree, scope_chapter );
            
            current_string_list := current_item[ 3 ];
            
            chapter_info[ 1 ] := scope_chapter;
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@Section" then
            
            ##Flush current node.
            if IsBound( current_item ) then AutoDoc_Flush( current_item ); fi;
            
            scope_section := ReplacedString( current_command[ 2 ], " ", "_" );
            
            SectionInTree( AUTOMATIC_DOCUMENTATION.tree, scope_chapter, scope_section );
            
            current_item := [ "Section", scope_chapter, scope_section, [ ] ];
            
            current_string_list := current_item[ 4 ];
            
            chapter_info[ 2 ] := scope_section;
            
            continue;
            
        fi;
        
        if current_command = "@EndSection" then
            
            if not IsBound( scope_section ) then
                
                Error( "No section set" );
                
            fi;
            
            if IsBound( current_item ) then AutoDoc_Flush( current_item ); fi;
            
            current_item := [ "Chapter", chapter_info[ 1 ], [ ] ];
            
            current_string_list := current_item[ 3 ];
            
            Unbind( scope_section );
            
            Unbind( chapter_info[ 2 ] );
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@BeginGroup" then
            
            if IsBound( current_item ) then AutoDoc_Flush( current_item ); fi;
            
            Unbind( current_item );
            
            if current_command[ 2 ] = "" then
                
                AUTOMATIC_DOCUMENTATION.groupnumber := AUTOMATIC_DOCUMENTATION.groupnumber + 1;
                
                current_command[ 2 ] := Concatenation( "AutoDoc_generated_group", String( AUTOMATIC_DOCUMENTATION.groupnumber ) );
                
            fi;
            
            scope_group := ReplacedString( current_command[ 2 ], " ", "_" );
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@EndGroup" then
            
            if IsBound( current_item ) then AutoDoc_Flush( current_item, chapter_info ); fi;
            
            Unbind( current_item );
            
            Unbind( scope_group );
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@Description" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].description := [ ];
            
            current_string_list := current_item[ 2 ].description;
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@ReturnValue" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].return_value := current_command[ 2 ];
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@Arguments" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].arguments := current_command[ 2 ];
            
            continue;
            
        fi;
        
        ## This should be deprecated by now.
        if current_command[ 1 ] = "@Label" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].label := current_command[ 2 ];
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@FunctionLabel" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].function_label := current_command[ 2 ];
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@Group" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].group := current_command[ 2 ];
            
            continue;
            
        fi;
        
        if current_command[ 1 ] = "@ChapterInfo" then
            
            current_item := AutoDoc_Prepare_Item_Record( current_item, chapter_info );
            
            current_item[ 2 ].chapter_info := SplitString( current_command[ 2 ], "," );
            
            current_item[ 2 ].chapter_info := List( current_item[ 2 ].chapter_info, i -> ReplacedString( AutoDoc_RemoveSpacesAndComments( i ), " ", "_" ) );
            
            continue;
            
        fi;
        
    od;
    
    return;
    
end );