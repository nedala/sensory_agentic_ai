namespace PoPilotAddin
{
    partial class PromptRibbon : Microsoft.Office.Tools.Ribbon.RibbonBase
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        public PromptRibbon()
            : base(Globals.Factory.GetRibbonFactory())
        {
            InitializeComponent();
        }

        /// <summary> 
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Component Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.button1 = this.Factory.CreateRibbonButton();
            this.SuspendLayout();
            // 
            // button1
            // 
            this.button1.Label = "PoPiloT Prompt";
            this.button1.Name = "button1";
            this.button1.ShowImage = true;
            this.button1.Click += new Microsoft.Office.Tools.Ribbon.RibbonControlEventHandler(this.button1_Click);
            // 
            // PromptRibbon
            // 
            this.Name = "PromptRibbon";
            // 
            // PromptRibbon.OfficeMenu
            // 
            this.OfficeMenu.Items.Add(this.button1);
            this.RibbonType = "Microsoft.PowerPoint.Presentation";
            this.Load += new Microsoft.Office.Tools.Ribbon.RibbonUIEventHandler(this.Ribbon1_Load);
            this.ResumeLayout(false);

        }

        #endregion

        internal Microsoft.Office.Tools.Ribbon.RibbonButton button1;
    }

    partial class ThisRibbonCollection
    {
        internal PromptRibbon Ribbon1
        {
            get { return this.GetRibbon<PromptRibbon>(); }
        }
    }
}
