module DynTask

  SOFTWARE={}

  def self.software_init(force=false)

    unless SOFTWARE[:R]
      if RUBY_PLATFORM=~/mingw32/
        cmd=Dir[File.join(ENV["HomeDrive"],"Program Files","R","**","R.exe")]
        SOFTWARE[:R]=cmd[0] unless cmd.empty?
      else
        cmd=`type "R"`
        SOFTWARE[:R]=cmd.strip.split(" ")[2] unless cmd.empty?
      end
    end

    unless SOFTWARE[:Rscript]
      if RUBY_PLATFORM=~/mingw32/
        cmd=Dir[File.join(ENV["HomeDrive"],"Program Files","R","**","Rscript.exe")]
        SOFTWARE[:Rscript]=cmd[0] unless cmd.empty?
      else
        cmd=`type "Rscript"`
        SOFTWARE[:R]=cmd.strip.split(" ")[2] unless cmd.empty?
      end
    end

    unless SOFTWARE[:ruby]
      cmd=`type "ruby"`
      SOFTWARE[:ruby]=cmd.strip.split(" ")[2] unless cmd.empty?
    end

    unless SOFTWARE[:pdflatex]
      cmd=`type "pdflatex"`
      if RUBY_PLATFORM =~ /msys/
        SOFTWARE[:pdflatex]="pdflatex"
      else
        SOFTWARE[:pdflatex]=cmd.empty? ? "pdflatex" : cmd.strip.split(" ")[2]
      end
    end
    
    unless SOFTWARE[:pandoc]
      if File.exist? File.join(ENV["HOME"],".cabal","bin","pandoc")
        SOFTWARE[:pandoc]=File.join(ENV["HOME"],".cabal","bin","pandoc")
      else
        cmd = `which pandoc`.strip
        SOFTWARE[:pandoc]=cmd unless cmd.empty?
        #cmd=`type "pandoc"`
        #SOFTWARE[:pandoc]=cmd.strip.split(" ")[2] unless cmd.empty?
      end
    end
  
    unless SOFTWARE[:ttm]
      cmd=`type "ttm"`
      SOFTWARE[:ttm]=cmd.strip.split(" ")[2] unless cmd.empty?
    end
     
  end

  def self.software
    SOFTWARE
  end

  def self.software?(software)
    software - SOFTWARE.keys
  end

  def self.pdflatex
    # this has to be initialized each time you need pdflatex since TEXINPUTS could change!
    if ENV['TEXINPUTS']
      "env TEXINPUTS=#{ENV['TEXINPUTS']}" + (RUBY_PLATFORM=~/mingw32/ ? "; " : " ") + SOFTWARE[:pdflatex] 
    else 
      SOFTWARE[:pdflatex]
    end
  end

  def self.R
    SOFTWARE[:R]
  end

  self.software_init
  
end