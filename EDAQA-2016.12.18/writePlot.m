function writePlot(X_label, Y_label, title_string, filename_figure, foldername_HTML, subfoldername_figures, OUTPUT_HTML_HANDLE, figure_width_pixels, varargin)
%WRITEPLOT Writes a plot to a PNG file and links this to an HTML page
%   Input arguments are self-explanatory
%
%   If input is [], then it won't be set (e.g., if you do NOT want a title
%   set). This is needed sometimes for subplots, where setting the axis,
%   etc. must be done outside of this function
%
% INPUT ARGUMENTS
%  OUTPUT_HTML_HANDLE    File handle to HTML file that is already open
% 
%
% CREDITS
%  Ian Kleckner
%  ian.kleckner@gmail.com
%  Northeastern University
%
% CHANGELOG
%  2012/05/?? Start coding
%  2013/03/19 Update to output MATLAB .fig too
%  2013/12/13 If an input is empty (i.e., []) then the option will not be
%  set

    if( ~isempty(X_label) )
        xlabel(X_label);
    end
    
    if( ~isempty(Y_label) )
        ylabel(Y_label);
    end
    
    if( ~isempty(title_string) )
        title(title_string);
    end

    filename_figure_full = sprintf('%s/%s/%s', foldername_HTML, subfoldername_figures, filename_figure);
    print(gcf, '-dpng', '-r150', filename_figure_full);
    
    if( ~isempty(varargin) )
        if( ~isempty(varargin{1}) )
            hgsave(gcf, [filename_figure_full,'.fig']);
        end
    end
    
    filename_figure_html = sprintf('%s/%s', subfoldername_figures, filename_figure);

    %fprintf(OUTPUT_HTML_HANDLE, '\n<br />');
    %fprintf(OUTPUT_HTML_HANDLE, '\n<br />');
    fprintf(OUTPUT_HTML_HANDLE, sprintf('\n<a href="%s"><img src="%s" width="%d"/></a>', filename_figure_html, filename_figure_html, figure_width_pixels));
    
    fprintf('\nWrote %s', filename_figure);
end
