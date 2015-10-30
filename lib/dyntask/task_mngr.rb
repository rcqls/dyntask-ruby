# encoding: UTF-8
require 'dyntask/software'
require "fileutils"

module DynTask

  @@task_mngr=nil

  def self.add_task(task)
    @@task_mngr ||= DynTask::TaskMngr.new
    @@task_mngr.add_task(task)
  end

  def self.save_tasks(task_basename)
    return unless @@task_mngr
    @@task_mngr.save_tasks(task_basename)
  end

  def self.read_tasks(task_filename)
    @@task_mngr ||= DynTask::TaskMngr.new
    @@task_mngr.load_user_task_plugins
    @@task_mngr.read_tasks(task_filename)
  end

  def self.cfg_dir
    root=File.join(ENV["HOME"],".dyntask")
    {
      :root => root,
      :etc => File.join(root,"etc"),
      :share => File.join(root,"share"),
      :tasks => File.join(root,"share","tasks"),
      :plugins => File.join(root,"share","plugins")
    }
  end

  def self.wait_for_file(filename,wait_loop_number = 20, wait_loop_time = 0.5,verbose=false)
    cpt=0
    while !File.exists? filename and cpt < wait_loop_number
      p "wait: #{cpt}"
      sleep wait_loop_time
      cpt+=1
    end
    ## return succeed
    File.exists? filename
  end

  class TaskMngr

    # TODO: to put outside to be extended by users!
    TASKS=["pdflatex","pandoc","png","dyn","sh"]
    TASK_EXT=".task_"

    def initialize
      init_tasks
    end

     def init_tasks
      @tasks=[]
    end

    ## Comment on writing task:
    ## task is just a ruby hash containing at least :cmd key to describe the
    ## command type. Other keys are for completing the task related to command :cmd
    ## However, :source and :target are recommanded keynames for describing source and target filename

    ## possibly add condition to check before applying command+options
    def add_task(task)
      @tasks << task
    end

    def save_tasks(task_basename)
      task_filename=task_basename+TASK_EXT+@tasks[0][:cmd].to_s
      File.open(task_filename,"w") do |f|
        f << @tasks.inspect
      end 
    end

    def write_tasks(task_basename,tasks)
      @tasks=tasks
      save_tasks(task_basename)
    end

    ## maybe to maintain only one task, remove current task when the new one is created
    def read_tasks(task_filename)
      @task_filename=task_filename
      @workdir=File.dirname(@task_filename)
      @tasks=Object.class_eval(File.read(@task_filename))
      ##p @tasks
      if @tasks.length>=1
        @task=@tasks.shift #first task to deal with
        ##p @task
        make_task
        if @tasks.length>=1
          dirname=File.dirname(task_filename)
          basename=File.basename(task_filename,".*")
          task_basename=File.join(dirname,basename)
          save_tasks(task_basename)
        end
        # remove since it is executed!
        FileUtils.rm(task_filename)
      end
    end

    ## if option to not remove taskfiles, this is a clean!
    def task_clean_taskfiles(task_filename)
      dirname=File.dirname(task_filename)
      basename=File.basename(task_filename,TASK_EXT+"*")
      
      Dir[File.join(dirname,basename+TASK_EXT+"*")].each do |f|
        FileUtils.rm(f)
      end
    end

    def load_user_task_plugins
      Dir[File.join(DynTask.cfg_dir[:plugins],"*.rb")].each {|lib| require lib} if File.exists? DynTask.cfg_dir[:plugins] 
    end

    def info_file(filename)
      return {} unless filename
      filename=File.join(@workdir,filename[1..-1]) if filename =~ /^\%/

      ##p filename

      res = {
        dirname: File.dirname(filename),
        extname: File.extname(filename),
        basename: File.basename(filename,".*")
      }
      res[:filename]=res[:basename]+res[:extname]
      res
    end

    def make_task

      if @task[:source]
        #p [:info,@task[:source]]
        @source=info_file(@task[:source])
        #p [:source,@source]
        @basename=@source[:basename]
        @extname=@source[:extname]
        @dirname=@source[:dirname]
        @filename=@source[:filename]
      end 

      @target=info_file(@task[:target]) if @task[:target]

       
      cd_new

      method("make_"+@task[:cmd].to_s).call

      # case @task[:cmd].to_s
      # when "sh"
      #   make_sh
      # when "dyn"
      #   make_dyn
      # when "pdflatex"
      #   make_pdf
      # when "pandoc"
      #   make_pandoc
      # when "png"
      #   make_png
      # end

      cd_old
        
    end

    def cd_new
      @curdir=Dir.pwd
      Dir.chdir(@workdir)
    end

    def cd_old
      Dir.chdir(@curdir)
    end

    # make sh

    def make_sh
      shell_opts=@task[:shell_opts] || ""
      script_opts=@task[:script_opts] || ""
      `sh #{shell_opts} #{source[:filename]} #{script_opts}`
    end

    # make dyn

    def make_dyn
      opts = @task[:options] || ""
      p [:dyn_cmd,"dyn #{opts} #{@filename}"]
      `dyn #{opts} #{@filename}`
    end

    # make pdf

    def make_pdf
      nb_pass = @task[:nb_pass] || 1
      echo_mode=@task[:echo] || false
      ok=true
      if @task[:content]
        file.open(@basename+".tex","w") do |f|
          f << @task[:content]
        end
      else
        ## Just in case of synchronisation delay!
        wait_time=@task[:wait_loop_time] || 0.5
        wait_nb=@task[:wait_loop_nb] || 20
        ok=DynTask.wait_for_file(@basename+".tex",wait_nb,wait_time)
      end
      if ok
        nb_pass.times {|i| make_pdflatex(echo_mode) }
      else
        puts "Warning: no way to apply pdflatex since #{@basename+'.tex'} does not exist!"
      end
    end

    # make pdflatex

    def make_pdflatex(echo_mode=false)
      unless File.exists? @basename+".tex"
        msg="No pdflatex #{@basename} in #{@dirname} since file does not exist!"
        print "\n==> "+msg
      end
      if File.read(@basename+".tex").empty?
        msg="No pdflatex #{@basename} in #{@dirname} since empty file!"
        print "\n==> "+msg
        ###$dyn_logger.write("ERROR pdflatex: "+msg+"\n") unless Dyndoc.cfg_dyn[:dyndoc_mode]==:normal
        return ""
      end
      print "\n==> #{DynTask.pdflatex} #{@basename} in #{@dirname}"

      out=`#{DynTask.pdflatex} -halt-on-error -file-line-error -interaction=nonstopmode #{@basename}`
      out=out.b if RUBY_VERSION >= "1.9" #because out is not necessarily utf8 encoded  
      out=out.split("\n")
      puts out if echo_mode
      if out[-2].include? "Fatal error"
        #if Dyndoc.cfg_dyn[:dyndoc_mode]==:normal
        #  print " -> NOT OKAY!!!\n==> "
        #  puts out[-4...-1]
        #  raise SystemExit 
        #end
      else 
        print " -> OKAY!!!\n"
        ###@cfg[:created_docs] << @basename+".pdf" #( @dirname.empty? ? "" : @dirname+"/" ) + @basename+".pdf"
      end
    end

    # make pandoc

    def make_pandoc
      mode=@task[:options][:mode]
      
      if @basename =~ /\_(md|tex)2(odt|docx|beamer|s5|dzslides|slideous|slidy|revealjs)$/ or (pandoc_mode=PANDOC_CMDS.include? mode)
        #p [@basename,$1,$2,pandoc_mode]
        if pandoc_mode
          mode =~ /(md|tex)2(odt|docx|beamer|s5|dzslides|slideous|slidy|revealjs)$/
        else
          @basename = @basename[0..(@basename.length-$1.length-$2.length-3)] unless pandoc_mode
        end
        #p @basename
         
        format_doc=$1.to_sym
        format_output=$2.to_sym
        cfg_pandoc=nil

        if File.exist? (cfg_pandoc_rbfile=File.join(DynTask.cfg_dir[:share],"pandoc","config.rb"))
          cfg_pandoc=Object.class_eval(File.read(cfg_pandoc_rbfile))
        end

        p [format_doc.to_s , format_output.to_s]
        cmd_pandoc_options,pandoc_file_output,pandoc_file_input=[],"",nil
        case format_doc.to_s + "2" + format_output.to_s
        when "md2odt"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2odt"] : []
          pandoc_file_output=@basename+append_doc+".odt"
        when "md2docx"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2docx"] : ["-s","-S"]
          pandoc_file_output=@basename+append_doc+".docx"
        when "tex2docx"
          pandoc_file_input=@filename
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["tex2docx"] : ["-s"]
          pandoc_file_output=@basename+append_doc+".docx"
        when "md2beamer"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2beamer"] : ["-t","beamer"]
          pandoc_file_output=@basename+append_doc+".pdf"
        when "md2dzslides"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2dzslides"] : ["-s","--mathml","-i","-t","dzslides"]
          pandoc_file_output=@basename+append_doc+".html"
        when "md2slidy"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2slidy"] : ["-s","--webtex","-i","-t","slidy"]
          pandoc_file_output=@basename+append_doc+".html"  
        when "md2s5"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2s5"] : ["-s","--self-contained","--webtex","-i","-t","s5"]
          pandoc_file_output=@basename+append_doc+".html"
        when "md2revealjs"
          cmd_pandoc_options=cfg_pandoc ? cfg_pandoc["md2revealjs"] : ["-s","--self-contained","--webtex","-i","-t","revealjs"]
          pandoc_file_output=@basename+append_doc+".html"
        when "md2slideous"
          cmd_pandoc_options=["-s","--mathjax","-i","-t","slideous"]
          pandoc_file_output=@basename+append_doc+".html"
        end
      end
     
      opts=cmd_pandoc_options+["-o",pandoc_file_output]
    
      if pandoc_file_input
        opts << pandoc_file_input
        #p [:make_pandoc_input, opts.join(" ")]
        Converter.pandoc(nil,opts.join(" "))
      else
        @content=File.read(@filename)
        #p [:make_pandoc_content, opts.join(" "),@content]
        Converter.pandoc(@content,opts.join(" "))
      end
      ## @cfg[:created_docs] << @cfg[:pandoc_file_output]
    end



    # make png

    def make_png
      make_dvipng
    end

    # make latex and dvipng 

    def make_dvipng
        system "latex #{@basename}.tex"
        print "\nlatex #{@basename}.tex -> ok\n"
        system "dvipng --nogssafer #{@basename}.dvi -o #{@basename}.png"
        print "\ndvipng --nogssafer #{@basename}.dvi -o #{@basename}.png -> ok\n"
    end

    # make ttm
    
    def make_ttm
#puts "make_ttm:begin"
      DynTask::Converter.ttm(File.read(@task[:filename]))
    end

  end
end
