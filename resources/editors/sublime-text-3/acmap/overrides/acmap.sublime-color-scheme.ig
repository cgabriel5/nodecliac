// Instructions:

// Add the following ACMAP scheme overrides to your '.sublime-color-scheme'
// for a better syntax highlighting experience.

{
	"name": "Flag Name, Template String Decor (keyword like highlighting)",
	"scope": "support.type.flag-name.acmap, support.type.placeholder-name.acmap, source.acmap punctuation.section.interpolation, source.acmap punctuation.separator.comma, source.acmap punctuation.accessor, entity.name.setting.acmap",
	"foreground": "var(purple)"
},
{
	"name": "Black: Assignment Operator, Pipe Delimiter, Flag Boolean Indicator (base text like highlighting)",
	"scope": "keyword.operator.assignment.acmap, punctuation.separator.pipe.acmap, keyword.operator.assignment.boolean.acmap, entity.other.command.acmap",
	"foreground": "var(default)",
	"font_style": "none"
},
{
	"name": "Italicize Command",
	"scope": "entity.other.command.acmap",
	"font_style": "italic"
}
