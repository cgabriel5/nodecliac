package formatter

import (
	ps "github.com/cgabriel5/compiler/utils/parsetools"
	"github.com/cgabriel5/compiler/utils/slices"
	"github.com/cgabriel5/compiler/utils/structs"
	"strings"
)

type Flag = structs.Flag
type StateParse = structs.StateParse
type Token = structs.Token

func indent(type_ string, count int,
	ichar byte, iamount int,
	MXP *map[string]int) string {
	var amount = count
	if amount == 0 {
		amount = (*MXP)[type_]
	}
	return strings.Repeat(string(ichar), amount*iamount)
}

func prevtoken(S *StateParse, tid int, skip *[]string /*={"tkNL"}*/) int {
	for ttid := tid - 1; ttid > -1; ttid-- {
		// [https://stackoverflow.com/a/18203895]
		index := slices.Index(len(*skip), func(i int) bool {
			return (*skip)[i] == S.LexerData.Tokens[ttid].Kind
		})
		// [https://stackoverflow.com/a/63735707]
		if index == -1 {
			return ttid
		}
	}
	return -1
}

func Formatter(S *StateParse,
	branches *[][]Token,
	cchains *[][][]int,
	flags *map[int][]Flag,
	settings *[][]int) (string, string, string, string,
	string, string, map[string]string, string) {

	fmt_ := S.Args.Fmt
	// igc := S.Args.Igc

	tokens := &(S.LexerData.Tokens)
	// ttypes := &(S.LexerData.Ttypes)
	// ttids := &(S.LexerData.Ttids)
	// dtids := &(S.LexerData.Dtids)

	// Indentation level multipliers.
	var MXP = map[string]int{
		"tkCMT":    0,
		"tkCMD":    0,
		"tkFLG":    1,
		"tkFOPT":   2,
		"tkBRC":    0,
		"tkNL":     0,
		"tkSTN":    0,
		"tkVAR":    0,
		"tkBRC_RP": 1,
		"tkBRC_LP": 2,
	}

	var NO_NL_CMT = []string{"tkNL", "tkCMT"}
	var ft_tkTYPES_NONE = []string{}
	var ft_tkTYPES_0 = []string{"tkNL"}
	var ft_tkTYPES_1 = []string{"tkSTN", "tkVAR"}
	var ft_tkTYPES_2 = []string{"tkASG", "tkSTR", "tkAVAL"}
	var ft_tkTYPES_3 = []string{"tkFVAL", "tkSTR", "tkDLS", "tkTBD"}
	var ft_tkTYPES_4 = []string{"tkDLS", "tkASG"}

	ichar := fmt_.Ichar
	iamount := fmt_.Iamount

	var cleaned = []string{}
	for _, branch := range *branches {
		parentkind := branch[0].Kind

		first_assignment := false
		level := 0

		brc_lp_count := 0
		group_open := false

		j := 0
		for _, leaf := range branch {
			tid := leaf.Tid
			kind := leaf.Kind
			line := leaf.Line

			//// Settings / Variables

			if slices.Contains(ft_tkTYPES_1, parentkind) {
				if kind == "tkTRM" {
					continue
				}

				if tid != 0 {
					ptk := &(S.LexerData.Tokens[prevtoken(S, tid, &ft_tkTYPES_0)])
					dline := line - ptk.Line
					if slices.Contains(ft_tkTYPES_2, kind) {
						if ptk.Kind == "tkCMT" {
							cleaned = append(cleaned, "\n")
							if dline > 1 {
								cleaned = append(cleaned, "\n")
							}
						}
						cleaned = append(cleaned, " ")
					} else {
						if dline == 0 {
							cleaned = append(cleaned, " ")
						} else if dline == 1 {
							cleaned = append(cleaned, "\n")
						} else {
							cleaned = append(cleaned, "\n\n")
						}
					}
				}

				cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				//// Command chains

			} else if parentkind == "tkCMD" {

				if tid != 0 {
					ptk := &((*tokens)[prevtoken(S, tid, &ft_tkTYPES_0)])
					dline := line - ptk.Line

					if dline == 1 {
						cleaned = append(cleaned, "\n")
					} else if dline > 1 {
						if !group_open {
							cleaned = append(cleaned, "\n")
							cleaned = append(cleaned, "\n")

							// [TODO] Add format settings to customize formatting.
							// For example, collapse newlines in flag scopes?
							// if level > 0: cleaned.pop()
						}
					}
				}

				// When inside an indentation level or inside parenthesis,
				// append a space before every token to space things out.
				// However, because this is being done lazily, some token
				// conditions must be skipped. The skippable cases are when
				// a '$' precedes a string (""), i.e. a '$"command"'. Or
				// when an eq-sign precedes a '$', i.e. '=$("cmd")',
				if (level > 0 || brc_lp_count == 1) &&
					slices.Contains(ft_tkTYPES_3, kind) {
					ptk := &((*tokens)[prevtoken(S, tid, &NO_NL_CMT)])
					pkind := ptk.Kind

					if pkind != "tkBRC_LP" && cleaned[len(cleaned)-1] != " " &&
						!((kind == "tkSTR" && pkind == "tkDLS") ||
							(kind == "tkDLS" && pkind == "tkASG")) {
						cleaned = append(cleaned, " ")
					}
				}

				if kind == "tkBRC_LC" {
					group_open = true
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkBRC_RC" {
					group_open = false
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkDCMA" && !first_assignment {
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))
					// Append newline after group is cloased.
					// if !group_open cleaned = append(cleaned, "\n")

				} else if kind == "tkASG" && !first_assignment {
					first_assignment = true
					cleaned = append(cleaned, " ")
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))
					cleaned = append(cleaned, " ")

				} else if kind == "tkBRC_LB" {
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))
					level = 1

				} else if kind == "tkBRC_RB" {
					level = 0
					first_assignment = false
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkFLG" {
					if level > 0 {
						cleaned = append(cleaned, indent(kind, level, ichar, iamount, &MXP))
					}
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkKYW" {
					if level > 0 {
						cleaned = append(cleaned, indent(kind, level, ichar, iamount, &MXP))
					}
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))
					cleaned = append(cleaned, " ")

				} else if kind == "tkFOPT" {
					level = 2
					cleaned = append(cleaned, indent(kind, level, ichar, iamount, &MXP))
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkBRC_LP" {
					brc_lp_count += 1
					ptk := &((*tokens)[prevtoken(S, tid, &ft_tkTYPES_0)])
					pkind := ptk.Kind
					if !slices.Contains(ft_tkTYPES_4, pkind) {
						scope_offset := 0 // int(pkind == "tkCMT")
						if pkind == "tkCMT" {
							scope_offset = 1
						}
						cleaned = append(cleaned, indent(kind, level+scope_offset, ichar, iamount, &MXP))
					}
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkBRC_RP" {
					brc_lp_count -= 1
					if level == 2 && brc_lp_count == 0 &&
						branch[j-1].Kind != "tkBRC_LP" {
						cleaned = append(cleaned, indent(kind, level-1, ichar, iamount, &MXP))
						level = 1
					}
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else if kind == "tkCMT" {
					ptk := (*tokens)[prevtoken(S, leaf.Tid, &ft_tkTYPES_NONE)].Kind
					atk := (*tokens)[prevtoken(S, tid, &ft_tkTYPES_0)].Kind
					if ptk == "tkNL" {
						scope_offset := 0
						if atk == "tkASG" {
							scope_offset = 1
						}
						cleaned = append(cleaned, indent(kind, level+scope_offset, ichar, iamount, &MXP))
					} else {
						cleaned = append(cleaned, " ")
					}
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

				} else {
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))
				}

				//// Comments

			} else if parentkind == "tkCMT" {
				if tid != 0 {
					ptk := &((*tokens)[prevtoken(S, tid, &ft_tkTYPES_0)])
					dline := line - ptk.Line

					if dline == 1 {
						cleaned = append(cleaned, "\n")
					} else {
						cleaned = append(cleaned, "\n")
						cleaned = append(cleaned, "\n")
					}
				}
				cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))

			} else {
				if kind != "tkTRM" {
					cleaned = append(cleaned, ps.Tkstr(S, leaf.Tid))
				}
			}

			j++
		}
	}

	// Return empty values to maintain parity with acdef.py.

	formatted := strings.Join(cleaned, "") + "\n"
	var oPlaceholders = make(map[string]string)

	return "", "", "", "", "", formatted, oPlaceholders, ""
}
